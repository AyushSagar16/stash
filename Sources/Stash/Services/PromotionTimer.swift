import Foundation
import OSLog

@MainActor
final class PromotionTimer {
    private let log = Logger(subsystem: "com.stash.app", category: "Promotion")
    private let store: TaskStore
    private var timer: Timer?

    init(store: TaskStore) {
        self.store = store
    }

    /// Run the L2→L1 scan immediately, then every 60s.
    func start() {
        timer?.invalidate()
        scan()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scan()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func scan() {
        do {
            let due = try store.l2DueForPromotion()
            for task in due {
                try store.move(task, to: .L1)
                log.info("auto-promoted \(task.id, privacy: .public) L2→L1")
            }
        } catch {
            log.error("scan failed: \(String(describing: error), privacy: .public)")
        }
    }
}
