import Foundation

enum Tier: String, Codable, CaseIterable, Identifiable, Sendable {
    case L1, L2, L3

    var id: String { rawValue }

    var label: String {
        switch self {
        case .L1: "L1 — next hour"
        case .L2: "L2 — next 3–5h"
        case .L3: "L3"
        }
    }

    /// Default offset from `createdAt` to `dueAt` for tasks added to this tier.
    /// Used so the auto-promotion timer knows when an L2 task should slide into L1.
    var defaultDueOffset: TimeInterval? {
        switch self {
        case .L1: 60 * 60          // 1h
        case .L2: 5 * 60 * 60      // 5h
        case .L3: nil
        }
    }

    /// Cycles L1 → L2 → L3 → L1 for the Tab severity picker.
    var next: Tier {
        switch self {
        case .L1: .L2
        case .L2: .L3
        case .L3: .L1
        }
    }
}

enum TaskStatus: String, Codable, Sendable {
    case open, done
}
