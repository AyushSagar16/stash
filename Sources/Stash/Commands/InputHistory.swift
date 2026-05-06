import Foundation

@MainActor
@Observable
final class InputHistory {
    private(set) var entries: [String] = []
    private var cursor: Int? = nil

    func append(_ entry: String) {
        // Avoid storing immediate duplicates.
        if entries.last != entry { entries.append(entry) }
        cursor = nil
    }

    /// Returns the previous (older) entry, or nil if at the top.
    func previous() -> String? {
        guard !entries.isEmpty else { return nil }
        let target = (cursor ?? entries.count) - 1
        guard target >= 0 else { return nil }
        cursor = target
        return entries[target]
    }

    /// Returns the next (newer) entry, an empty string when scrolling past the most recent, or nil if no cursor is set.
    func next() -> String? {
        guard let c = cursor else { return nil }
        let target = c + 1
        if target < entries.count {
            cursor = target
            return entries[target]
        } else {
            cursor = nil
            return ""
        }
    }

    func resetCursor() {
        cursor = nil
    }
}
