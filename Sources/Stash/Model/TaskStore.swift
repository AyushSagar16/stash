import Foundation
import SwiftData
import OSLog

@MainActor
final class TaskStore {
    private let log = Logger(subsystem: "com.stash.app", category: "TaskStore")

    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let url = Self.storeURL()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let schema = Schema([StashTask.self])
        let config = ModelConfiguration(schema: schema, url: url)
        self.container = try ModelContainer(for: schema, configurations: [config])
        self.context = ModelContext(container)
        log.info("TaskStore opened at \(url.path)")
    }

    static func storeURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appending(path: "stash/Stash.store")
    }

    // MARK: - Mutations

    @discardableResult
    func add(title: String, tier: Tier, dueAt: Date? = nil, tags: [String] = [], recurrenceRule: String? = nil) throws -> StashTask {
        let task = StashTask(
            id: makeUniqueId(),
            title: title,
            tier: tier,
            dueAt: dueAt,
            tags: tags,
            recurrenceRule: recurrenceRule
        )
        context.insert(task)
        try context.save()
        return task
    }

    func markDone(_ task: StashTask) throws {
        task.status = .done
        task.doneAt = .now
        try context.save()
    }

    func move(_ task: StashTask, to tier: Tier) throws {
        task.tier = tier
        if let offset = tier.defaultDueOffset {
            task.dueAt = .now.addingTimeInterval(offset)
        } else {
            task.dueAt = nil
        }
        try context.save()
    }

    func delete(_ task: StashTask) throws {
        context.delete(task)
        try context.save()
    }

    func addTag(_ tag: String, to task: StashTask) throws {
        if !task.tags.contains(tag) { task.tags.append(tag) }
        try context.save()
    }

    func clear(tier: Tier) throws {
        let tierRaw = tier.rawValue
        let openRaw = TaskStatus.open.rawValue
        let predicate = #Predicate<StashTask> { task in
            task.tierRaw == tierRaw && task.statusRaw == openRaw
        }
        try context.delete(model: StashTask.self, where: predicate)
        try context.save()
    }

    // MARK: - Queries

    func openTasks(in tier: Tier) throws -> [StashTask] {
        let tierRaw = tier.rawValue
        let openRaw = TaskStatus.open.rawValue
        let predicate = #Predicate<StashTask> { task in
            task.tierRaw == tierRaw && task.statusRaw == openRaw
        }
        let descriptor = FetchDescriptor<StashTask>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    func allOpen() throws -> [Tier: [StashTask]] {
        var result: [Tier: [StashTask]] = [:]
        for tier in Tier.allCases {
            result[tier] = try openTasks(in: tier)
        }
        return result
    }

    func find(idPrefix: String) throws -> StashTask? {
        let descriptor = FetchDescriptor<StashTask>(
            predicate: #Predicate { $0.id.starts(with: idPrefix) }
        )
        return try context.fetch(descriptor).first
    }

    func search(_ query: String) throws -> [StashTask] {
        let q = query.lowercased()
        let descriptor = FetchDescriptor<StashTask>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).filter { task in
            task.title.lowercased().contains(q) || task.id.contains(q)
        }
    }

    func recentlyDone(days: Int = 7) throws -> [StashTask] {
        let doneRaw = TaskStatus.done.rawValue
        let cutoff = Date.now.addingTimeInterval(TimeInterval(-days * 86_400))
        let sentinel = Date.distantPast
        let predicate = #Predicate<StashTask> { task in
            task.statusRaw == doneRaw && (task.doneAt ?? sentinel) > cutoff
        }
        let descriptor = FetchDescriptor<StashTask>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.doneAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// L2 tasks whose due time has crossed into the next hour — used by PromotionTimer.
    func l2DueForPromotion() throws -> [StashTask] {
        let l2Raw = Tier.L2.rawValue
        let openRaw = TaskStatus.open.rawValue
        let horizon = Date.now.addingTimeInterval(60 * 60)
        let sentinel = Date.distantFuture
        let predicate = #Predicate<StashTask> { task in
            task.tierRaw == l2Raw && task.statusRaw == openRaw && (task.dueAt ?? sentinel) <= horizon
        }
        return try context.fetch(FetchDescriptor(predicate: predicate))
    }

    /// Completed tasks older than `days` — used by HistoryPruner.
    func donePruneCandidates(olderThan days: Int = 7) throws -> [StashTask] {
        let doneRaw = TaskStatus.done.rawValue
        let cutoff = Date.now.addingTimeInterval(TimeInterval(-days * 86_400))
        let sentinel = Date.distantFuture
        let predicate = #Predicate<StashTask> { task in
            task.statusRaw == doneRaw && (task.doneAt ?? sentinel) < cutoff
        }
        return try context.fetch(FetchDescriptor(predicate: predicate))
    }

    // MARK: - IDs

    func makeUniqueId() -> String {
        for _ in 0..<64 {
            let candidate = StashTask.makeShortId()
            let descriptor = FetchDescriptor<StashTask>(
                predicate: #Predicate { $0.id == candidate }
            )
            if (try? context.fetch(descriptor).isEmpty) == true {
                return candidate
            }
        }
        return String(UUID().uuidString.prefix(6).lowercased())
    }
}
