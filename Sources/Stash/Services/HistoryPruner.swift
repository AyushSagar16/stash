import Foundation
import OSLog

@MainActor
final class HistoryPruner {
    private let log = Logger(subsystem: "com.stash.app", category: "Pruner")
    private let store: TaskStore
    private let retentionDays: Int
    private var timer: Timer?

    init(store: TaskStore, retentionDays: Int = 7) {
        self.store = store
        self.retentionDays = retentionDays
    }

    /// Run an immediate prune, then every 6 hours.
    func start() {
        timer?.invalidate()
        prune()
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.prune()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func prune() {
        do {
            let toRemove = try store.donePruneCandidates(olderThan: retentionDays)
            for task in toRemove { try store.delete(task) }
            if !toRemove.isEmpty {
                log.info("pruned \(toRemove.count, privacy: .public) old completed tasks")
            }
        } catch {
            log.error("prune failed: \(String(describing: error), privacy: .public)")
        }
    }
}
