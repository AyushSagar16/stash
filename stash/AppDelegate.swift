import Cocoa
import SwiftUI
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var overlayPanel: OverlayPanel?
    private var focusPanel: NSPanel?
    private var hotkeyService: HotkeyService?
    private var escalationService: EscalationService?
    private var notificationService: NotificationService?
    private var clickOutsideMonitor: Any?
    private var localKeyMonitor: Any?
    private var appState = AppState()
    private var isOverlayVisible = false
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize services
        notificationService = NotificationService()
        escalationService = EscalationService(appState: appState, notificationService: notificationService!)

        // Initialize menu bar
        menuBarController = MenuBarController(
            appState: appState,
            onShowStash: { [weak self] in self?.toggleOverlay() },
            onFocusMode: { [weak self] in self?.toggleFocusMode() },
            onSettings: { [weak self] in self?.showSettings() }
        )

        // Create overlay panel (must be created before hotkey fires)
        setupOverlayPanel()

        // Register global hotkey (⌥Space via Carbon)
        hotkeyService = HotkeyService { [weak self] in
            DispatchQueue.main.async {
                self?.toggleOverlay()
            }
        }

        // Load initial data
        appState.reload()
    }

    // MARK: - Overlay

    private func setupOverlayPanel() {
        overlayPanel = OverlayPanel()
    }

    func toggleOverlay() {
        if isOverlayVisible {
            dismissOverlay()
        } else {
            showOverlay()
        }
    }

    private func showOverlay() {
        guard let panel = overlayPanel else { return }

        // Reset overlay mode
        appState.overlayMode = .input
        appState.reload()

        // Center on the active screen
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame
        let panelWidth: CGFloat = 520
        let inputHeight: CGFloat = 280
        let x = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2
        let y = screenFrame.origin.y + (screenFrame.height - inputHeight) / 2 + 100
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: inputHeight), display: false)

        // Set content
        let overlayView = OverlayView(appState: appState, onDismiss: { [weak self] in
            self?.dismissOverlay()
        }, onFocusMode: { [weak self] in
            self?.dismissOverlay()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.toggleFocusMode()
            }
        }, onSettings: { [weak self] in
            self?.dismissOverlay()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.showSettings()
            }
        }, onResizePanel: { [weak self] newHeight in
            self?.resizePanel(to: newHeight)
        })

        panel.contentView = NSHostingView(rootView: overlayView)

        // CRITICAL: Activate the app first so the panel can appear above other apps.
        // For LSUIElement (accessory) apps, panels are invisible unless the app is activated.
        NSApp.activate(ignoringOtherApps: true)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        focusOverlayInput(in: panel)

        // Animate in
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1.0
        }

        isOverlayVisible = true

        // Haptic on open
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)

        // Monitor for clicks outside the panel
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.dismissOverlay()
        }

        // Monitor for Escape key locally
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.dismissOverlay()
                return nil
            }
            return event
        }
    }

    private func focusOverlayInput(in panel: NSPanel, attemptsRemaining: Int = 12) {
        guard attemptsRemaining > 0 else { return }

        if let contentView = panel.contentView,
           let textField = firstEditableTextField(in: contentView) {
            panel.makeFirstResponder(textField)
            if panel.firstResponder === textField {
                return
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            self?.focusOverlayInput(in: panel, attemptsRemaining: attemptsRemaining - 1)
        }
    }

    private func firstEditableTextField(in root: NSView) -> NSTextField? {
        if let textField = root as? NSTextField, textField.isEditable, !textField.isHidden {
            return textField
        }

        for subview in root.subviews {
            if let found = firstEditableTextField(in: subview) {
                return found
            }
        }

        return nil
    }

    private func resizePanel(to newHeight: CGFloat) {
        guard let panel = overlayPanel else { return }
        let currentFrame = panel.frame
        // Grow downward from current top edge
        let newY = currentFrame.origin.y + currentFrame.height - newHeight
        let newFrame = NSRect(x: currentFrame.origin.x, y: newY, width: currentFrame.width, height: newHeight)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .default)
            panel.animator().setFrame(newFrame, display: true)
        }
    }

    private func dismissOverlay() {
        guard let panel = overlayPanel, isOverlayVisible else { return }

        // Remove monitors
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
            clickOutsideMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }

        isOverlayVisible = false

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1.0
        })
    }

    // MARK: - Focus Mode

    private func toggleFocusMode() {
        if let fp = focusPanel, fp.isVisible {
            fp.orderOut(nil)
            focusPanel = nil
            return
        }

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame
        let panelWidth: CGFloat = 320
        let panelHeight: CGFloat = 300

        let panel = NSPanel(
            contentRect: NSRect(
                x: screenFrame.maxX - panelWidth - 20,
                y: screenFrame.maxY - panelHeight - 20,
                width: panelWidth,
                height: panelHeight
            ),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true

        let focusView = FocusModeView(appState: appState) { [weak self] in
            self?.focusPanel?.orderOut(nil)
            self?.focusPanel = nil
        }

        panel.contentView = NSHostingView(rootView: focusView)
        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        focusPanel = panel
    }

    // MARK: - Settings

    private func showSettings() {
        // If settings window already exists, bring it forward
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(appState: appState)
        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 400, height: 500)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Stash Settings"
        window.contentView = hostingView
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }
}
