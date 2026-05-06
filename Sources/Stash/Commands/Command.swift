import Foundation

enum Command: Equatable {
    case noop
    case add(tier: Tier, title: String, dueAt: Date?, tags: [String])
    case done(idPrefix: String)
    case move(idPrefix: String, to: Tier)
    case remove(idPrefix: String)
    case find(query: String)
}

enum CommandError: Error, LocalizedError {
    case missingArgument(String)
    case invalidTier(String)
    case quoteUnclosed
    case invalidTime(String)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .missingArgument(let s): "missing argument: \(s)"
        case .invalidTier(let s):     "invalid tier: \(s) (use l1, l2, or l3)"
        case .quoteUnclosed:          "unclosed quote"
        case .invalidTime(let s):     "invalid time: \(s)"
        case .notFound(let s):        "no task matching '\(s)'"
        }
    }
}

enum CommandResult {
    case noop
    case added(StashTask)
    case markedDone(StashTask)
    case moved(StashTask, to: Tier)
    case removed(String)
    case searched(query: String, results: [StashTask])

    var message: String {
        switch self {
        case .noop:                          ""
        case .added(let t):                  "added \(t.id) → \(t.tier.rawValue)"
        case .markedDone(let t):             "done \(t.id) — \(t.title)"
        case .moved(let t, let tier):        "moved \(t.id) → \(tier.rawValue)"
        case .removed(let id):               "removed \(id)"
        case .searched(let q, let r):        "\(r.count) match\(r.count == 1 ? "" : "es") for '\(q)'"
        }
    }
}
