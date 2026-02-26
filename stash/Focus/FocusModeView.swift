import SwiftUI

struct FocusModeView: View {
    @ObservedObject var appState: AppState
    let onClose: () -> Void

    private var l1Tasks: [StashTask] {
        appState.activeTasks(in: .l1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Circle()
                    .fill(Tier.l1.color)
                    .frame(width: 7, height: 7)

                Text("L1 Focus")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider().background(Color.white.opacity(0.1))

            if l1Tasks.isEmpty {
                VStack(spacing: 4) {
                    Text("No L1 tasks")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("All clear!")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(l1Tasks) { task in
                        FocusTaskRow(task: task) {
                            appState.completeTask(task)
                            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(width: 320)
        .background(
            VisualEffectBlur()
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 5)
    }
}

// MARK: - Focus Task Row

struct FocusTaskRow: View {
    let task: StashTask
    let onComplete: () -> Void

    @State private var isHovered = false
    @State private var isCompleted = false

    var body: some View {
        HStack(spacing: 8) {
            // Checkbox circle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCompleted = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onComplete()
                }
            }) {
                Circle()
                    .strokeBorder(isCompleted ? Color.green : Color.gray.opacity(0.4), lineWidth: 1.5)
                    .background(
                        Circle().fill(isCompleted ? Color.green.opacity(0.3) : Color.clear)
                    )
                    .frame(width: 16, height: 16)
                    .overlay {
                        if isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.green)
                        }
                    }
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(isCompleted ? .white.opacity(0.4) : .white.opacity(0.9))
                .strikethrough(isCompleted, color: .white.opacity(0.3))
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? Color.white.opacity(0.04) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
