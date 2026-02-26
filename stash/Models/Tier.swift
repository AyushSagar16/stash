import SwiftUI

enum Tier: String, Codable, CaseIterable, Sendable {
    case l1
    case l2
    case l3
    case mem

    var label: String {
        switch self {
        case .l1: return "L1 Cache"
        case .l2: return "L2 Cache"
        case .l3: return "L3 Cache"
        case .mem: return "Main Memory"
        }
    }

    var shortLabel: String {
        switch self {
        case .l1: return "L1"
        case .l2: return "L2"
        case .l3: return "L3"
        case .mem: return "MEM"
        }
    }

    var color: Color {
        switch self {
        case .l1: return Color(red: 1.0, green: 0.271, blue: 0.227)    // #FF453A
        case .l2: return Color(red: 1.0, green: 0.624, blue: 0.039)    // #FF9F0A
        case .l3: return Color(red: 0.188, green: 0.820, blue: 0.345)  // #30D158
        case .mem: return Color(red: 0.388, green: 0.388, blue: 0.400) // #636366
        }
    }

    var nsColor: NSColor {
        switch self {
        case .l1: return NSColor(red: 1.0, green: 0.271, blue: 0.227, alpha: 1.0)
        case .l2: return NSColor(red: 1.0, green: 0.624, blue: 0.039, alpha: 1.0)
        case .l3: return NSColor(red: 0.188, green: 0.820, blue: 0.345, alpha: 1.0)
        case .mem: return NSColor(red: 0.388, green: 0.388, blue: 0.400, alpha: 1.0)
        }
    }

    /// Time threshold (in seconds) before auto-escalation is considered
    var escalationThreshold: TimeInterval {
        switch self {
        case .l1: return 0           // L1 doesn't escalate further
        case .l2: return 2 * 3600    // 2 hours
        case .l3: return 5 * 3600    // 5 hours
        case .mem: return 0          // MEM never auto-escalates
        }
    }

    /// Maximum number of tasks in the target tier before escalation is blocked
    var targetTierCapacity: Int {
        switch self {
        case .l1: return 0   // N/A
        case .l2: return 3   // Escalates to L1 if L1 has < 3
        case .l3: return 3   // Escalates to L2 if L2 has < 3
        case .mem: return 0  // N/A
        }
    }

    /// The tier this task would escalate to
    var escalationTarget: Tier? {
        switch self {
        case .l1: return nil
        case .l2: return .l1
        case .l3: return .l2
        case .mem: return nil  // MEM never auto-escalates
        }
    }

    /// Next tier when cycling with Tab (L1 → L2 → L3 → MEM → L1)
    var next: Tier {
        switch self {
        case .l1: return .l2
        case .l2: return .l3
        case .l3: return .mem
        case .mem: return .l1
        }
    }

    /// Previous tier (for demoting / snoozing)
    var previous: Tier? {
        switch self {
        case .l1: return .l2
        case .l2: return .l3
        case .l3: return .mem
        case .mem: return nil
        }
    }

    /// Next tier up (for promoting)
    var promoted: Tier? {
        switch self {
        case .l1: return nil
        case .l2: return .l1
        case .l3: return .l2
        case .mem: return .l3
        }
    }

    /// Sort order for display (L1 first)
    var sortOrder: Int {
        switch self {
        case .l1: return 0
        case .l2: return 1
        case .l3: return 2
        case .mem: return 3
        }
    }
}
