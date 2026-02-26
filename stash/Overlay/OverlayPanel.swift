import Cocoa

/// A floating panel for the Stash overlay.
/// Floats above other windows and can receive keyboard focus.
class OverlayPanel: NSPanel {
    override init(
        contentRect: NSRect = NSRect(x: 0, y: 0, width: 520, height: 280),
        styleMask: NSWindow.StyleMask = [.borderless, .fullSizeContentView],
        backing: NSWindow.BackingStoreType = .buffered,
        defer flag: Bool = false
    ) {
        super.init(contentRect: contentRect, styleMask: styleMask, backing: backing, defer: flag)
        configure()
    }

    private func configure() {
        isFloatingPanel = true
        level = .popUpMenu  // Above everything except screen saver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        animationBehavior = .utilityWindow

        // No title bar, no traffic lights
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Dismiss on Escape key
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            orderOut(nil)
        } else {
            super.keyDown(with: event)
        }
    }
}
