import SwiftData
import SwiftUI

struct ContentView: View {
    let runner: CommandRunner

    @Query(sort: \StashTask.createdAt) private var allTasks: [StashTask]

    @State private var input: String = ""
    @State private var hint: String = ""
    @State private var mode: InputMode = .add
    @State private var pendingTier: Tier = .L1
    @State private var selectedTaskID: String?
    @State private var inputHistory = InputHistory()
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CommandLineView(
                input: $input,
                hint: $hint,
                focused: $inputFocused,
                mode: mode,
                pendingTier: pendingTier,
                suggestion: currentSuggestion,
                onSubmit: handleSubmit,
                onTab: handleTab,
                onShiftTab: handleShiftTab,
                onAcceptSuggestion: handleAcceptSuggestion,
                onArrowUp: handleArrowUp,
                onArrowDown: handleArrowDown
            )

            if !visibleTiers.isEmpty {
                Divider().opacity(0.25)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(visibleTiers) { tier in
                            TierSectionView(
                                tier: tier,
                                tasks: tasks(for: tier),
                                selectedTaskID: mode == .complete ? selectedTaskID : nil,
                                onComplete: handleComplete
                            )
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: Palette.panelMaxHeight)
            }
        }
        .frame(width: Palette.panelWidth)
        .background(VisualEffectView())
        .clipShape(RoundedRectangle(cornerRadius: Palette.cornerRadius, style: .continuous))
        .onAppear { inputFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .stashPanelDidShow)) { _ in
            inputFocused = true
            input = ""
            hint = ""
            mode = .add
            pendingTier = .L1
            selectedTaskID = nil
            inputHistory.resetCursor()
        }
    }

    // MARK: - Derived data

    private func tasks(for tier: Tier) -> [StashTask] {
        allTasks
            .filter { $0.tier == tier && $0.status == .open }
            .sorted(by: { $0.createdAt < $1.createdAt })
    }

    /// Tiers that currently have at least one open task — drives dynamic panel height.
    private var visibleTiers: [Tier] {
        Tier.allCases.filter { !tasks(for: $0).isEmpty }
    }

    /// Open tasks across all tiers in display order — used for complete-mode arrow navigation.
    private var orderedOpenTasks: [StashTask] {
        Tier.allCases.flatMap { tasks(for: $0) }
    }

    private var currentSuggestion: Suggestion? {
        guard mode == .add else { return nil }
        let lookup = orderedOpenTasks.map { (id: $0.id, title: $0.title) }
        return Suggestions.complete(input, tasks: lookup)
    }

    // MARK: - Submit / commands

    private func handleSubmit() {
        switch mode {
        case .add:    submitAdd()
        case .complete: submitComplete()
        }
    }

    private func submitAdd() {
        let raw = input.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return }
        inputHistory.append(raw)

        switch runner.run(raw, defaultTier: pendingTier) {
        case .success(let result):
            hint = result.message
            input = ""
            pendingTier = .L1
        case .failure(let error):
            hint = error.localizedDescription
            // Keep the input so user can correct it.
        }
    }

    private func submitComplete() {
        guard let id = selectedTaskID,
              let task = orderedOpenTasks.first(where: { $0.id == id }) else { return }

        // Choose the next selection before mutation removes the row from the list.
        let nextID = neighborID(after: task)

        switch runner.run("done \(task.id)", defaultTier: pendingTier) {
        case .success(let result):
            hint = result.message
            selectedTaskID = nextID
        case .failure(let error):
            hint = error.localizedDescription
        }
    }

    private func neighborID(after task: StashTask) -> String? {
        let list = orderedOpenTasks
        guard let i = list.firstIndex(where: { $0.id == task.id }) else { return nil }
        if i + 1 < list.count { return list[i + 1].id }
        if i - 1 >= 0 { return list[i - 1].id }
        return nil
    }

    private func handleComplete(_ task: StashTask) {
        let nextID = neighborID(after: task)
        switch runner.run("done \(task.id)", defaultTier: pendingTier) {
        case .success(let result):
            hint = result.message
            if selectedTaskID == task.id { selectedTaskID = nextID }
        case .failure(let error):
            hint = error.localizedDescription
        }
    }

    // MARK: - Key handlers

    private func handleTab() {
        guard mode == .add else { return }
        pendingTier = pendingTier.next
    }

    private func handleShiftTab() {
        switch mode {
        case .add:
            mode = .complete
            if selectedTaskID == nil || !orderedOpenTasks.contains(where: { $0.id == selectedTaskID }) {
                selectedTaskID = orderedOpenTasks.first?.id
            }
        case .complete:
            mode = .add
            inputFocused = true
        }
    }

    private func handleAcceptSuggestion() {
        guard let suggestion = currentSuggestion else { return }
        input = suggestion.fullText
    }

    private func handleArrowUp() {
        switch mode {
        case .add:
            if let prev = inputHistory.previous() { input = prev }
        case .complete:
            moveSelection(by: -1)
        }
    }

    private func handleArrowDown() {
        switch mode {
        case .add:
            if let nxt = inputHistory.next() { input = nxt }
        case .complete:
            moveSelection(by: 1)
        }
    }

    private func moveSelection(by delta: Int) {
        let list = orderedOpenTasks
        guard !list.isEmpty else { selectedTaskID = nil; return }
        let currentIndex = list.firstIndex(where: { $0.id == selectedTaskID }) ?? 0
        let target = max(0, min(list.count - 1, currentIndex + delta))
        selectedTaskID = list[target].id
    }
}
