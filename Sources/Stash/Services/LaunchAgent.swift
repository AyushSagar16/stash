import Foundation
import ServiceManagement
import OSLog

@MainActor
enum LaunchAgent {
    private static let log = Logger(subsystem: "com.stash.app", category: "LaunchAgent")

    /// Register the main app to start at login. The system creates a
    /// LaunchAgent under `~/Library/LaunchAgents/` pointing at the app bundle.
    /// Note: for the LaunchAgent to be effective across reboots, the app bundle
    /// must live in a stable location (e.g. /Applications/Stash.app).
    static func registerForLaunchAtLogin() {
        let service = SMAppService.mainApp
        switch service.status {
        case .enabled:
            log.info("launch-at-login: already enabled")
        case .notRegistered, .notFound:
            do {
                try service.register()
                log.info("launch-at-login: registered")
            } catch {
                log.error("launch-at-login register failed: \(error.localizedDescription, privacy: .public)")
            }
        case .requiresApproval:
            log.info("launch-at-login: needs user approval — System Settings → General → Login Items")
        @unknown default:
            log.warning("launch-at-login: unknown status (\(service.status.rawValue, privacy: .public))")
        }
    }

    static func unregister() {
        do {
            try SMAppService.mainApp.unregister()
            log.info("launch-at-login: unregistered")
        } catch {
            log.error("launch-at-login unregister failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
