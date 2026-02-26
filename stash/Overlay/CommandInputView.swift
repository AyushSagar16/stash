import SwiftUI
import AppKit

struct CommandInputView: View {
    @ObservedObject var appState: AppState
    let onDismiss: () -> Void
    let onSwitchMode: (OverlayMode) -> Void
    let onFocusMode: () -> Void
    let onSettings: () -> Void

    @State private var inputText = ""
    @State private var selectedTier: Tier = .l1
    @State private var showCommandPalette = false
    @State private var shakeOffset: CGFloat = 0
    @State private var errorMessage: String?
    @State private var errorOpacity: Double = 0
    @FocusState private var isInputFocused: Bool

    private var previewTasks: [StashTask] {
        appState.activeTasks(in: selectedTier)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Prompt line
            HStack(spacing: 8) {
                // Tier indicator dot
                Circle()
                    .fill(selectedTier.color)
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.15), value: selectedTier)

                Text("›")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))

                TextField("add task...", text: $inputText)
                    .font(.system(size: 14, design: .monospaced))
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .focused($isInputFocused)
                    .onSubmit {
                        handleSubmit()
                    }
                    .onChange(of: inputText) { _, newValue in
                        showCommandPalette = newValue.hasPrefix("/")
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .offset(x: shakeOffset)

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.horizontal, 42)
                    .padding(.bottom, 8)
                    .opacity(errorOpacity)
                    .transition(.opacity)
            }

            // Command palette dropdown
            if showCommandPalette {
                CommandPaletteView(
                    inputText: $inputText,
                    onSelect: { command in
                        handleCommand(command)
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Tier indicator bar
            HStack(spacing: 12) {
                ForEach(Tier.allCases, id: \.self) { tier in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(tier == selectedTier ? tier.color : tier.color.opacity(0.3))
                            .frame(width: 6, height: 6)
                        Text(tier.shortLabel)
                            .font(.system(size: 10, weight: tier == selectedTier ? .semibold : .regular, design: .monospaced))
                            .foregroundColor(tier == selectedTier ? tier.color : .gray.opacity(0.5))
                    }
                }

                Spacer()

                Text("Tab to switch tier • Click task to complete • Esc to close")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            if !showCommandPalette {
                Divider()
                    .background(Color.white.opacity(0.08))

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(selectedTier.color)
                            .frame(width: 7, height: 7)

                        Text("\(selectedTier.shortLabel) Tasks")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(selectedTier.color)

                        Text("\(previewTasks.count)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                    if previewTasks.isEmpty {
                        Text("No \(selectedTier.shortLabel) tasks")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(previewTasks) { task in
                                    PreviewTaskRow(task: task) {
                                        completePreviewTask(task)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 102)
                    }
                }
            }
        }
        .onAppear {
            requestInputFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            requestInputFocus()
        }
        .onKeyPress(.tab) {
            cycleTier()
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    // MARK: - Actions

    private func cycleTier() {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedTier = selectedTier.next
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    private func requestInputFocus() {
        DispatchQueue.main.async {
            isInputFocused = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isInputFocused = true
        }
    }

    private func handleSubmit() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            // Shake animation for empty input
            shakeAnimation()
            return
        }

        if trimmed.hasPrefix("/") {
            // Command mode
            handleCommandString(trimmed)
        } else {
            // Create task
            appState.addTask(title: trimmed, tier: selectedTier)
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            inputText = ""
        }
    }

    private func completePreviewTask(_ task: StashTask) {
        appState.completeTask(task)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    private func handleCommandString(_ command: String) {
        let parts = command.lowercased().split(separator: " ", maxSplits: 1)
        let cmd = String(parts.first ?? "")
        let arg = parts.count > 1 ? String(parts[1]) : nil

        switch cmd {
        case "/list":
            onSwitchMode(.list)
            inputText = ""
        case "/done":
            onSwitchMode(.done)
            inputText = ""
        case "/focus":
            onFocusMode()
            onDismiss()
            inputText = ""
        case "/clear":
            appState.clearCompleted()
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            inputText = ""
            showSuccess("Completed tasks cleared")
        case "/settings":
            onSettings()
            onDismiss()
            inputText = ""
        case "/help":
            onSwitchMode(.help)
            inputText = ""
        case "/snooze":
            if let arg = arg {
                if let task = appState.tasks.first(where: { $0.title.lowercased().contains(arg) }) {
                    appState.snoozeTask(task)
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                    inputText = ""
                } else {
                    showError("Task not found")
                }
            } else {
                showError("Usage: /snooze [task name]")
            }
        case "/promote":
            if let arg = arg {
                if let task = appState.tasks.first(where: { $0.title.lowercased().contains(arg) }) {
                    appState.promoteTask(task)
                    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                    inputText = ""
                } else {
                    showError("Task not found")
                }
            } else {
                showError("Usage: /promote [task name]")
            }
        default:
            showError("Unknown command")
        }
    }

    private func handleCommand(_ command: String) {
        inputText = command + " "
        showCommandPalette = false
        if !command.contains("[") {
            // Immediate commands without args
            handleCommandString(command)
        }
    }

    private func shakeAnimation() {
        withAnimation(.default) {
            shakeOffset = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.default) {
                shakeOffset = -8
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.default) {
                shakeOffset = 5
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.default) {
                shakeOffset = 0
            }
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        withAnimation(.easeIn(duration: 0.15)) {
            errorOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.3)) {
                errorOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                errorMessage = nil
            }
        }
    }

    private func showSuccess(_ message: String) {
        errorMessage = message
        withAnimation(.easeIn(duration: 0.15)) {
            errorOpacity = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                errorOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                errorMessage = nil
            }
        }
    }
}

private struct PreviewTaskRow: View {
    let task: StashTask
    let onComplete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onComplete) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.45))

                Text(task.title)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)

                Spacer()

                Text(task.relativeTimeString)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
