import Cocoa
import SwiftUI
import Combine

/// Manages the menu bar status item, icon tinting, right-click menu, and pulse animation.
@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem?
    private let appState: AppState
    private let onShowStash: () -> Void
    private let onFocusMode: () -> Void
    private let onSettings: () -> Void
    private var cancellables = Set<AnyCancellable>()
    private var pulseTimer: Timer?

    init(
        appState: AppState,
        onShowStash: @escaping () -> Void,
        onFocusMode: @escaping () -> Void,
        onSettings: @escaping () -> Void
    ) {
        self.appState = appState
        self.onShowStash = onShowStash
        self.onFocusMode = onFocusMode
        self.onSettings = onSettings
        setupStatusItem()
        observeState()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "square.3.layers.3d.down.right", accessibilityDescription: "Stash")
            image?.isTemplate = true
            button.image = image
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            onShowStash()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        let showItem = NSMenuItem(title: "Show Stash", action: #selector(menuShowStash), keyEquivalent: "")
        showItem.keyEquivalentModifierMask = .option
        showItem.target = self
        menu.addItem(showItem)

        let focusItem = NSMenuItem(title: "Focus Mode", action: #selector(menuFocusMode), keyEquivalent: "")
        focusItem.target = self
        menu.addItem(focusItem)

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(menuSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Stash", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil // Reset so left-click still works
    }

    @objc private func menuShowStash() { onShowStash() }
    @objc private func menuFocusMode() { onFocusMode() }
    @objc private func menuSettings() { onSettings() }
    @objc private func menuQuit() { NSApp.terminate(nil) }

    // MARK: - State Observation

    private func observeState() {
        appState.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.updateIconTint(tasks: tasks)
            }
            .store(in: &cancellables)

        appState.$lastEscalationTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                if time != nil {
                    self?.startPulseAnimation()
                }
            }
            .store(in: &cancellables)
    }

    private func updateIconTint(tasks: [StashTask]) {
        guard let button = statusItem?.button else { return }

        let hasL1 = tasks.contains { $0.tier == .l1 }
        let hasL2 = tasks.contains { $0.tier == .l2 }

        if hasL1 {
            button.contentTintColor = Tier.l1.nsColor
        } else if hasL2 {
            button.contentTintColor = Tier.l2.nsColor
        } else {
            button.contentTintColor = nil // System default
        }
    }

    // MARK: - Pulse Animation

    private func startPulseAnimation() {
        guard let button = statusItem?.button else { return }

        // Pulse for 60 seconds
        var elapsed: TimeInterval = 0
        pulseTimer?.invalidate()
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self, weak button] timer in
            elapsed += 1
            if elapsed > 60 {
                timer.invalidate()
                button?.alphaValue = 1.0
                self?.pulseTimer = nil
                return
            }
            // Subtle pulse
            let alpha: CGFloat = 0.5 + 0.5 * CGFloat(sin(elapsed * 3))
            button?.alphaValue = alpha
        }
    }
}
