import Foundation

enum CommandParser {

    /// Parses a raw input string. Bare text becomes an `.add` command at `defaultTier`,
    /// with inline `@time` and `#tag` tokens stripped out into structured fields.
    /// Recognised verbs (`done`, `mv`/`move`, `rm`/`del`/`delete`/`remove`, `find`/`search`)
    /// route to their respective commands instead.
    static func parse(_ raw: String, defaultTier: Tier) throws -> Command {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .noop }

        let tokens = try tokenize(trimmed)
        guard let head = tokens.first?.lowercased() else { return .noop }
        let rest = Array(tokens.dropFirst())

        switch head {
        case "done":
            guard let id = rest.first else { throw CommandError.missingArgument("id") }
            return .done(idPrefix: id)

        case "mv", "move":
            guard rest.count >= 2 else { throw CommandError.missingArgument("id and tier") }
            guard let tier = parseTier(rest[1]) else { throw CommandError.invalidTier(rest[1]) }
            return .move(idPrefix: rest[0], to: tier)

        case "rm", "del", "delete", "remove":
            guard let id = rest.first else { throw CommandError.missingArgument("id") }
            return .remove(idPrefix: id)

        case "find", "search":
            let q = rest.joined(separator: " ")
            guard !q.isEmpty else { throw CommandError.missingArgument("query") }
            return .find(query: q)

        default:
            // Bare text → add task at defaultTier, after pulling out inline @time / #tag.
            let parts = try parseAddArgs(tokens)
            guard !parts.title.isEmpty else { return .noop }
            return .add(tier: defaultTier, title: parts.title, dueAt: parts.due, tags: parts.tags)
        }
    }

    /// True when the input begins with one of the reserved verbs — used to decide
    /// whether an autocomplete match should be labelled "command" or "task".
    static func startsWithReservedVerb(_ raw: String) -> Bool {
        let lower = raw.lowercased()
        for verb in reservedVerbs {
            if lower == verb || lower.hasPrefix(verb + " ") { return true }
        }
        return false
    }

    static let reservedVerbs: [String] = [
        "done", "mv", "move", "rm", "del", "delete", "remove", "find", "search",
    ]

    // MARK: - tokenizer

    static func tokenize(_ s: String) throws -> [String] {
        var tokens: [String] = []
        var current = ""
        var inQuote = false

        for c in s {
            if inQuote {
                if c == "\"" {
                    tokens.append(current); current = ""; inQuote = false
                } else {
                    current.append(c)
                }
            } else if c == "\"" {
                if !current.isEmpty { tokens.append(current); current = "" }
                inQuote = true
            } else if c.isWhitespace {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else {
                current.append(c)
            }
        }
        if inQuote { throw CommandError.quoteUnclosed }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    // MARK: - helpers

    static func parseTier(_ raw: String) -> Tier? {
        switch raw.lowercased() {
        case "l1", "1": .L1
        case "l2", "2": .L2
        case "l3", "3": .L3
        default: nil
        }
    }

    private struct AddParts {
        let title: String
        let due: Date?
        let tags: [String]
    }

    /// Pull title (multi-word) plus inline `@time` and `#tag` tokens.
    private static func parseAddArgs(_ tokens: [String]) throws -> AddParts {
        var titleParts: [String] = []
        var due: Date?
        var tags: [String] = []
        for t in tokens {
            if t.hasPrefix("@") {
                guard let d = parseTime(String(t.dropFirst())) else { throw CommandError.invalidTime(t) }
                due = d
            } else if t.hasPrefix("#") {
                tags.append(String(t.dropFirst()))
            } else {
                titleParts.append(t)
            }
        }
        return AddParts(title: titleParts.joined(separator: " "), due: due, tags: tags)
    }

    /// Supports: `tomorrow`, `4pm`, `5:30am`, `9pm`. Returns the next occurrence in the future.
    static func parseTime(_ raw: String) -> Date? {
        let t = raw.lowercased()
        let cal = Calendar.current

        if t == "tomorrow" {
            let start = cal.startOfDay(for: .now)
            return start.addingTimeInterval(86_400 + 9 * 3_600) // 9am tomorrow
        }

        let pattern = #"^(\d{1,2})(?::(\d{2}))?(am|pm)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(t.startIndex..., in: t)
        guard let m = regex.firstMatch(in: t, range: range) else { return nil }

        func group(_ i: Int) -> String? {
            guard m.range(at: i).location != NSNotFound,
                  let r = Range(m.range(at: i), in: t) else { return nil }
            return String(t[r])
        }

        guard let hourStr = group(1), let hour = Int(hourStr) else { return nil }
        let minute = Int(group(2) ?? "0") ?? 0
        let ampm = group(3) ?? ""

        var h = hour
        if ampm == "pm", h < 12 { h += 12 }
        if ampm == "am", h == 12 { h = 0 }

        var comps = cal.dateComponents([.year, .month, .day], from: .now)
        comps.hour = h
        comps.minute = minute
        guard let date = cal.date(from: comps) else { return nil }
        return date < .now ? date.addingTimeInterval(86_400) : date
    }
}
