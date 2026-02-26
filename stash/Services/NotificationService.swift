import Foundation
import UserNotifications

/// Manages local notifications for task escalation alerts.
final class NotificationService: @unchecked Sendable {
    init() {
        requestAuthorization()
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("[Stash Notifications] Auth error: \(error.localizedDescription)")
            }
        }
    }

    func sendEscalationNotification(taskTitle: String, newTier: Tier) {
        let enabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        // Default to true if not set
        if UserDefaults.standard.object(forKey: "notificationsEnabled") == nil || enabled {
            let content = UNMutableNotificationContent()
            content.title = "Task Escalated"
            content.body = "\"\(taskTitle)\" escalated to \(newTier.shortLabel)"
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil  // Deliver immediately
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("[Stash Notifications] Failed to send: \(error.localizedDescription)")
                }
            }
        }
    }
}
