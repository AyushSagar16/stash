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
    private var updateChecker: UpdateChecker?
    private var updater: Updater?
    private var updateProgress: UpdateProgressWindow?
    private var sigUsr1Source: (any DispatchSourceSignal)?
    private var panelShownObserver: NSObjectProtocol?

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

        let updateChecker = UpdateChecker()
        updateChecker.onUpdateAvailable = { [weak self] release in
            self?.presentUpdatePrompt(release)
        }
        updateChecker.start()
        self.updateChecker = updateChecker

        let panel = OverlayPanel()

        let runner = CommandRunner(
            store: store,
            notifications: notifs
        )

        let hosting = StashHostingController(
            rootView: ContentView(runner: runner)
                .modelContainer(store.container)
        )
        hosting.stashPanel = panel
        panel.contentViewController = hosting
        self.panel = panel

        let monitor = HotkeyMonitor { [weak self] in
            self?.panel?.toggle()
        }
        monitor.install()
        self.hotkeyMonitor = monitor

        // Re-prompt for an available update every time the overlay opens.
        // The check itself is gated to ~6h cadence, so this just re-fires the
        // already-cached release.
        panelShownObserver = NotificationCenter.default.addObserver(
            forName: .stashPanelDidShow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateChecker?.requestPromptIfAvailable()
            }
        }

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

    private func presentUpdatePrompt(_ release: ReleaseInfo) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Stash \(release.tagName) is available"
        let trimmed = release.body?.trimmingCharacters(in: .whitespacesAndNewlines)
        alert.informativeText = trimmed.flatMap { $0.isEmpty ? nil : String($0.prefix(400)) }
            ?? "A new version of Stash is available."
        let installButton = alert.addButton(withTitle: "Install Now")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Skip This Version")

        if release.dmgAsset == nil {
            installButton.isEnabled = false
            alert.informativeText += "\n\n(No DMG asset on this release — install manually.)"
        }

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            runInstall(release)
        case .alertSecondButtonReturn:
            // "Later" — just dismiss. The prompt re-appears on the next overlay open.
            break
        case .alertThirdButtonReturn:
            UserDefaults.standard.set(release.normalizedVersion, forKey: "Stash.UpdateCheck.skippedVersion")
        default:
            break
        }
    }

    private func runInstall(_ release: ReleaseInfo) {
        let progress = UpdateProgressWindow()
        progress.show(message: UpdateStage.downloading.userFacing)
        self.updateProgress = progress

        let updater = Updater()
        self.updater = updater

        Task { @MainActor [weak self] in
            do {
                try await updater.install(release) { stage in
                    self?.updateProgress?.update(message: stage.userFacing)
                }
                // install() terminates the process on success — unreachable on the happy path.
            } catch {
                self?.updateProgress?.close()
                self?.updateProgress = nil
                self?.showInstallError(error, release: release)
            }
        }
    }

    private func showInstallError(_ error: Error, release: ReleaseInfo) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn't install the update"
        alert.informativeText = (error as? LocalizedError)?.errorDescription
            ?? error.localizedDescription
        alert.addButton(withTitle: "Open Release Page")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: release.htmlUrl) {
            NSWorkspace.shared.open(url)
        }
    }
}
