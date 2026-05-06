import AppKit
import Foundation
import OSLog
import SwiftUI

extension Notification.Name {
    static let stashPanelDidShow = Notification.Name("stash.panel.didShow")
    static let stashPanelDidHide = Notification.Name("stash.panel.didHide")
}

final class StashHostingController<Content: View>: NSHostingController<Content> {
    weak var stashPanel: OverlayPanel?
    /// Guards against the AppKit ↔ SwiftUI layout feedback loop:
    /// our resize triggers a new layout, which calls viewDidLayout, which
    /// would otherwise call resize again. The `< 1pt` tolerance in the
    /// dispatch below converges fittingSize jitter; this flag stops re-entry
    /// inside the same synchronous layout pass.
    private var isApplyingSize = false

    override func viewDidLayout() {
        super.viewDidLayout()
        guard let panel = stashPanel, !isApplyingSize else { return }
        let size = view.fittingSize
        guard size.width > 0, size.height > 0 else { return }
        let current = panel.frame.size
        if abs(current.width - size.width) < 1, abs(current.height - size.height) < 1 {
            return
        }
        isApplyingSize = true
        panel.adopt(contentSize: size)
        isApplyingSize = false
    }
}

final class OverlayPanel: NSPanel {
    /// Minimal/initial size before SwiftUI reports its real preferred size.
    static let initialSize = NSSize(width: 540, height: 56)

    private static let log = Logger(subsystem: "com.stash.app", category: "Panel")

    /// Y-coordinate of the panel's top edge, recomputed on each `show()`.
    /// Resizes preserve this so the panel grows downward (Spotlight-style).
    private var anchorTopY: CGFloat = 0

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.initialSize),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        configure()
    }

    private func configure() {
        // Float above all windows, including fullscreen apps.
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)))
        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]

        // Frameless / transparent so the SwiftUI vibrancy shows through.
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        // Behave like Spotlight: don't deactivate the previous app, hide on Esc.
        hidesOnDeactivate = false
        isFloatingPanel = true
        worksWhenModal = true
        isMovableByWindowBackground = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        recomputeAnchor()
        adopt(contentSize: fittedContentSize())
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .stashPanelDidShow, object: nil)
        Self.log.info("show() → isVisible=\(self.isVisible, privacy: .public) isKeyWindow=\(self.isKeyWindow, privacy: .public)")
    }

    func hide() {
        orderOut(nil)
        NotificationCenter.default.post(name: .stashPanelDidHide, object: nil)
        Self.log.info("hide()")
    }

    /// Esc dismiss.
    override func cancelOperation(_ sender: Any?) {
        hide()
    }

    /// Resize the panel to `size` while keeping its top edge anchored.
    /// Called by the hosting controller whenever SwiftUI's preferred size changes.
    func adopt(contentSize size: NSSize) {
        guard size.width > 0, size.height > 0 else { return }
        // No-op if the size hasn't actually changed — guards against any future
        // setFrame ↔ render feedback loop.
        if abs(frame.width - size.width) < 0.5,
           abs(frame.height - size.height) < 0.5 {
            return
        }
        layout(to: size)
    }

    private func fittedContentSize() -> NSSize {
        guard let view = contentViewController?.view else {
            return Self.initialSize
        }

        view.layoutSubtreeIfNeeded()
        let fitting = view.fittingSize
        let width = max(Self.initialSize.width, fitting.width)
        let height = max(Self.initialSize.height, fitting.height)
        return NSSize(width: width, height: height)
    }

    private func recomputeAnchor() {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = screen.visibleFrame
        // ~22% from the top of the visible area, mirroring Spotlight.
        anchorTopY = visible.maxY - visible.height * 0.22
    }

    private func layout(to size: NSSize) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = screen.visibleFrame
        let x = visible.midX - size.width / 2
        let y = anchorTopY - size.height
        setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}
