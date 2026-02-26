import SwiftUI
import Combine

/// Observable state for the entire app — shared across views.
@MainActor
final class AppState: ObservableObject {
    @Published var tasks: [StashTask] = []
    @Published var completedTasks: [StashTask] = []
    @Published var lastEscalationTime: Date?
    @Published var overlayMode: OverlayMode = .input

    func reload() {
        tasks = DatabaseManager.shared.fetchActiveTasks()
    }

    func reloadCompleted() {
        completedTasks = DatabaseManager.shared.fetchCompletedTasks()
    }

    func addTask(title: String, tier: Tier) {
        let task = StashTask(title: title, tier: tier)
        DatabaseManager.shared.addTask(task)
        reload()
    }

    func completeTask(_ task: StashTask) {
        DatabaseManager.shared.completeTask(id: task.id)
        reload()
    }

    func promoteTask(_ task: StashTask) {
        guard let newTier = task.tier.promoted else { return }
        DatabaseManager.shared.updateTier(id: task.id, newTier: newTier)
        reload()
    }

    func snoozeTask(_ task: StashTask) {
        guard let newTier = task.tier.previous else { return }
        DatabaseManager.shared.updateTier(id: task.id, newTier: newTier)
        reload()
    }

    func clearCompleted() {
        DatabaseManager.shared.clearCompleted()
        reloadCompleted()
    }

    func clearAllData() {
        DatabaseManager.shared.clearAllData()
        reload()
        reloadCompleted()
    }

    func activeTasks(in tier: Tier) -> [StashTask] {
        tasks.filter { $0.tier == tier }
    }

    var highestActiveTier: Tier? {
        for tier in [Tier.l1, .l2, .l3, .mem] {
            if tasks.contains(where: { $0.tier == tier }) {
                return tier
            }
        }
        return nil
    }
}
