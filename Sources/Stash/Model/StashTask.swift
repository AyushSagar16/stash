import Foundation
import SwiftData

@Model
final class StashTask {
    @Attribute(.unique) var id: String
    var title: String

    /// Raw string storage so SwiftData predicates can compare against captured constants
    /// (the predicate runtime rejects captured enum values).
    var tierRaw: String
    var statusRaw: String

    var createdAt: Date
    var dueAt: Date?
    var doneAt: Date?
    var tags: [String]
    var recurrenceRule: String?

    init(
        id: String,
        title: String,
        tier: Tier,
        status: TaskStatus = .open,
        createdAt: Date = .now,
        dueAt: Date? = nil,
        doneAt: Date? = nil,
        tags: [String] = [],
        recurrenceRule: String? = nil
    ) {
        self.id = id
        self.title = title
        self.tierRaw = tier.rawValue
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.dueAt = dueAt ?? tier.defaultDueOffset.map { createdAt.addingTimeInterval($0) }
        self.doneAt = doneAt
        self.tags = tags
        self.recurrenceRule = recurrenceRule
    }

    /// Generate a 3-character hex prefix. Caller must check uniqueness.
    static func makeShortId() -> String {
        let alphabet = Array("0123456789abcdef")
        return String((0..<3).map { _ in alphabet.randomElement()! })
    }
}

extension StashTask {
    var tier: Tier {
        get { Tier(rawValue: tierRaw) ?? .L3 }
        set { tierRaw = newValue.rawValue }
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }
}
