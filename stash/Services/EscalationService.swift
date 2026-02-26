import Foundation

/// Background service that automatically escalates tasks based on time-in-tier rules.
/// Runs every 5 minutes on a background queue.
@MainActor
final class EscalationService {
    private var timer: DispatchSourceTimer?
    private let appState: AppState
    private let notificationService: NotificationService

    init(appState: AppState, notificationService: NotificationService) {
        self.appState = appState
        self.notificationService = notificationService
        startTimer()
    }

    deinit {
        timer?.cancel()
    }

    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now() + 60, repeating: 300) // First check after 1 min, then every 5 mins
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.runEscalation()
            }
        }
        timer.resume()
        self.timer = timer
    }

    private func runEscalation() {
        let enabled = UserDefaults.standard.object(forKey: "escalationEnabled") == nil ||
                       UserDefaults.standard.bool(forKey: "escalationEnabled")
        guard enabled else { return }

        let tasks = appState.tasks
        let now = Date()
        var didEscalate = false

        for task in tasks {
            guard !task.isCompleted else { continue }
            guard let targetTier = task.tier.escalationTarget else { continue }

            let threshold = task.tier.escalationThreshold
            guard threshold > 0 else { continue }

            let timeInTier = now.timeIntervalSince(task.tierAssignedAt)
            guard timeInTier >= threshold else { continue }

            // Check capacity of target tier
            let targetCount = appState.activeTasks(in: targetTier).count
            guard targetCount < task.tier.targetTierCapacity else { continue }

            // Escalate!
            DatabaseManager.shared.updateTier(id: task.id, newTier: targetTier)
            notificationService.sendEscalationNotification(taskTitle: task.title, newTier: targetTier)
            didEscalate = true
        }

        if didEscalate {
            appState.reload()
            appState.lastEscalationTime = Date()
        }
    }
}
