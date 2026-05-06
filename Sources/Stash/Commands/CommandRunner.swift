import Foundation
import OSLog

@MainActor
struct CommandRunner {
    private static let log = Logger(subsystem: "com.stash.app", category: "CommandRunner")

    let store: TaskStore
    let notifications: NotificationScheduler

    func run(_ raw: String, defaultTier: Tier) -> Result<CommandResult, Error> {
        Result {
            let command = try CommandParser.parse(raw, defaultTier: defaultTier)
            return try execute(command)
        }
    }

    private func execute(_ command: Command) throws -> CommandResult {
        switch command {
        case .noop:
            return .noop

        case .add(let tier, let title, let due, let tags):
            let task = try store.add(title: title, tier: tier, dueAt: due, tags: tags, recurrenceRule: nil)
            let scheduler = notifications
            let createdTask = task
            Task { await scheduler.schedule(for: createdTask) }
            Self.log.info("added \(task.id, privacy: .public) → \(tier.rawValue, privacy: .public)")
            return .added(task)

        case .done(let prefix):
            guard let task = try store.find(idPrefix: prefix) else { throw CommandError.notFound(prefix) }
            try store.markDone(task)
            notifications.cancel(for: task.id)
            return .markedDone(task)

        case .move(let prefix, let to):
            guard let task = try store.find(idPrefix: prefix) else { throw CommandError.notFound(prefix) }
            try store.move(task, to: to)
            let scheduler = notifications
            let movedTask = task
            Task { await scheduler.schedule(for: movedTask) }
            return .moved(task, to: to)

        case .remove(let prefix):
            guard let task = try store.find(idPrefix: prefix) else { throw CommandError.notFound(prefix) }
            notifications.cancel(for: task.id)
            try store.delete(task)
            return .removed(prefix)

        case .find(let q):
            let results = try store.search(q)
            return .searched(query: q, results: results)
        }
    }
}
