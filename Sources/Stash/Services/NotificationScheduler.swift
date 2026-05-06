import Foundation
import UserNotifications
import OSLog

@MainActor
final class NotificationScheduler {
    private let log = Logger(subsystem: "com.stash.app", category: "Notif")
    private let leadTime: TimeInterval = 5 * 60   // notify 5 min before due

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            log.info("notification auth: \(granted, privacy: .public)")
        } catch {
            log.error("notification auth failed: \(error.localizedDescription)")
        }
    }

    /// Schedule a local notification `leadTime` before the task's due time.
    /// No-op for non-L1 tasks, completed tasks, or tasks whose lead-time has already passed.
    func schedule(for task: StashTask) async {
        guard task.tier == .L1, task.status == .open, let due = task.dueAt else { return }
        let fireAt = due.addingTimeInterval(-leadTime)
        let interval = fireAt.timeIntervalSinceNow
        guard interval > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Stash · L1 due soon"
        content.body = task.title
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.identifier(for: task.id),
            content: content,
            trigger: trigger
        )
        do {
            // Replace any existing scheduled notification for this task.
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [Self.identifier(for: task.id)]
            )
            try await UNUserNotificationCenter.current().add(request)
            log.info("notif scheduled for \(task.id, privacy: .public)")
        } catch {
            log.error("notif schedule failed: \(error.localizedDescription)")
        }
    }

    func cancel(for taskId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.identifier(for: taskId)]
        )
    }

    private static func identifier(for taskId: String) -> String {
        "stash.task.\(taskId)"
    }
}
