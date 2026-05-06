import AppKit
import ApplicationServices
import OSLog

@MainActor
final class HotkeyMonitor {
    private let log = Logger(subsystem: "com.stash.app", category: "Hotkey")
    private let onTrigger: () -> Void

    private var lastControlOnlyPress: TimeInterval = 0
    private let threshold: TimeInterval = 0.3
    private var keysSeenSinceControlPress: Set<UInt16> = []

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private static let controlKeyCode: UInt16 = 59

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    func install() {
        // Trigger the system Accessibility prompt on first launch.
        let trusted = isAccessibilityTrusted(prompt: true)
        if !trusted {
            log.warning("Accessibility permission not granted — global hotkey will not fire until enabled in System Settings → Privacy & Security → Accessibility.")
        }

        // Global: events from other apps. Requires Accessibility permission.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.flagsChanged, .keyDown]
        ) { [weak self] event in
            self?.handle(event)
        }

        // Local: events when our overlay is key. Lets the same hotkey close the panel.
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.flagsChanged, .keyDown]
        ) { [weak self] event in
            self?.handle(event)
            return event
        }

        log.info("Hotkey monitor installed (double-Control)")
    }

    deinit {
        if let g = globalMonitor { NSEvent.removeMonitor(g) }
        if let l = localMonitor  { NSEvent.removeMonitor(l) }
    }

    private func handle(_ event: NSEvent) {
        if event.type == .keyDown {
            keysSeenSinceControlPress.insert(event.keyCode)
            return
        }

        // .flagsChanged
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let onlyControl = flags == .control
        let cleared = flags.isEmpty

        if onlyControl, event.keyCode == Self.controlKeyCode {
            keysSeenSinceControlPress.removeAll()
            let now = event.timestamp
            if now - lastControlOnlyPress < threshold {
                onTrigger()
                lastControlOnlyPress = 0
            } else {
                lastControlOnlyPress = now
            }
        } else if cleared, !keysSeenSinceControlPress.isEmpty {
            // Control was released after another key was pressed — invalidate the tap.
            lastControlOnlyPress = 0
            keysSeenSinceControlPress.removeAll()
        }
    }

    @discardableResult
    func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }
}
