import Foundation

struct StashTask: Codable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var tier: Tier
    var isCompleted: Bool
    var createdAt: Date
    var tierAssignedAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        tier: Tier = .l1,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        tierAssignedAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.tier = tier
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.tierAssignedAt = tierAssignedAt
        self.completedAt = completedAt
    }

    /// Relative time string for display, e.g. "2h ago" or "just now"
    var relativeTimeString: String {
        let interval = Date().timeIntervalSince(createdAt)
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}
