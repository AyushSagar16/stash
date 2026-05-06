import AppKit

/// Small floating window with a spinner + status label, shown for the duration
/// of the auto-update download/install. Not modal — the install Task drives
/// updates by calling `update(message:)`, then `close()` runs only on error
/// (success path terminates the process before closing).
@MainActor
final class UpdateProgressWindow {
    private var window: NSWindow?
    private var label: NSTextField?

    func show(message: String) {
        if window != nil { return }

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.isIndeterminate = true
        spinner.controlSize = .small
        spinner.startAnimation(nil)
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        self.label = label

        let stack = NSStackView(views: [spinner, label])
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        stack.alignment = .centerY

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 64),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        win.title = "Stash Update"
        win.contentView = stack
        win.level = .floating
        win.isReleasedWhenClosed = false
        win.center()
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        self.window = win
    }

    func update(message: String) {
        label?.stringValue = message
    }

    func close() {
        window?.orderOut(nil)
        window = nil
        label = nil
    }
}
