import Foundation

/// Result of an autocomplete attempt against the current input.
enum Suggestion: Equatable {
    /// A reserved verb completion (e.g. `do` → `done `).
    case command(full: String)
    /// A task slug completion inside an id-verb command (e.g. `done a` → `done a3f `).
    case taskID(full: String, title: String)
    /// A bare-text completion that matches an existing open task title.
    case taskTitle(full: String, id: String)

    var fullText: String {
        switch self {
        case .command(let s):       s
        case .taskID(let s, _):     s
        case .taskTitle(let s, _):  s
        }
    }

    /// Short kind label rendered next to the input for context.
    var kindLabel: String {
        switch self {
        case .command:                    "command"
        case .taskID(_, let title):       "task: \(title)"
        case .taskTitle(_, let id):       "task: \(id)"
        }
    }
}

enum Suggestions {
    /// Reserved verbs the parser recognises. Trailing space lets `do` → `done ` flow naturally.
    private static let commandTemplates: [String] = [
        "done ", "mv ", "rm ", "find ",
    ]

    /// Verbs that take a task-id prefix as their first argument.
    private static let idVerbs = ["done ", "mv ", "rm "]

    /// Best completion for `input`, or nil if nothing matches.
    /// `tasks` is the live list of open tasks (used for slug + title matching).
    static func complete(_ input: String, tasks: [(id: String, title: String)]) -> Suggestion? {
        guard !input.isEmpty else { return nil }

        // 1. Reserved verb prefix → command suggestion (do → done ).
        if let template = commandTemplates.first(where: { $0.hasPrefix(input) && $0 != input }) {
            return .command(full: template)
        }

        // 2. Inside an id-verb, complete the task id.
        for verb in idVerbs where input.hasPrefix(verb) {
            let after = String(input.dropFirst(verb.count))
            if !after.contains(" ") {
                if let match = tasks.first(where: { $0.id.hasPrefix(after) && $0.id != after }) {
                    return .taskID(full: verb + match.id + " ", title: match.title)
                }
            }
        }

        // 3. Bare text → suggest an existing task title that shares the prefix.
        if !CommandParser.startsWithReservedVerb(input) {
            let lower = input.lowercased()
            if let match = tasks.first(where: {
                let t = $0.title.lowercased()
                return t.hasPrefix(lower) && t != lower
            }) {
                return .taskTitle(full: match.title, id: match.id)
            }
        }

        return nil
    }
}
