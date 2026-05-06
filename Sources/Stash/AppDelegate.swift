import AppKit
import OSLog
import SwiftData
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "com.stash.app", category: "AppDelegate")

    private var taskStore: TaskStore?
    private var panel: OverlayPanel?
    private var hotkeyMonitor: HotkeyMonitor?
    private var promotionTimer: PromotionTimer?
    private var historyPruner: HistoryPruner?
    private var notifications: NotificationScheduler?
    private var sigUsr1Source: (any DispatchSourceSignal)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        log.info("Stash launched (accessory mode)")

        // Register for launch-at-login. Effective only when the bundle lives in
        // a stable location (e.g. /Applications/Stash.app); from .build/* this
        // logs a status but won't actually fire on reboot.
        LaunchAgent.registerForLaunchAtLogin()

        let store: TaskStore
        do {
            store = try TaskStore()
        } catch {
            log.fault("Failed to open TaskStore: \(error.localizedDescription)")
            NSApp.terminate(nil)
            return
        }
        self.taskStore = store

        // Background services.
        let notifs = NotificationScheduler()
        self.notifications = notifs
        Task { await notifs.requestAuthorization() }

        let promotion = PromotionTimer(store: store)
        promotion.start()
        self.promotionTimer = promotion

        let pruner = HistoryPruner(store: store)
        pruner.start()
        self.historyPruner = pruner

        let panel = OverlayPanel()

        let runner = CommandRunner(
            store: store,
            notifications: notifs
        )

        let hosting = StashHostingController(
            rootView: ContentView(runner: runner)
                .modelContainer(store.container)
        )
        hosting.sizingOptions = [.preferredContentSize]
        hosting.onPreferredSizeChange = { [weak panel] size in
            panel?.adopt(contentSize: size)
        }
        panel.contentViewController = hosting
        self.panel = panel

        let monitor = HotkeyMonitor { [weak self] in
            self?.panel?.toggle()
        }
        monitor.install()
        self.hotkeyMonitor = monitor

        // Dev / scripting affordance: `kill -USR1 $(pgrep -x Stash)` toggles the overlay.
        // Useful before Accessibility permission is granted, and as a hook for shell aliases.
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { [weak self] in
            self?.log.info("SIGUSR1 received → toggle panel")
            self?.panel?.toggle()
        }
        source.resume()
        self.sigUsr1Source = source
    }
}
