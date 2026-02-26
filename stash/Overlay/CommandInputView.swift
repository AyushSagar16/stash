import SwiftUI

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

                Text("Tab to cycle • Esc to close")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .onAppear {
            isInputFocused = true
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
