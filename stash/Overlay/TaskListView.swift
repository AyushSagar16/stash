import SwiftUI

struct TaskListView: View {
    @ObservedObject var appState: AppState
    let onBack: () -> Void

    @State private var completedTaskIds: Set<UUID> = []

    private var groupedTasks: [(tier: Tier, tasks: [StashTask])] {
        let tiers: [Tier] = [.l1, .l2, .l3, .mem]
        return tiers.compactMap { tier in
            let tasks = appState.activeTasks(in: tier)
            return tasks.isEmpty ? nil : (tier: tier, tasks: tasks)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Tasks")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)

                Spacer()

                Button(action: onBack) {
                    Text("← back")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider().background(Color.white.opacity(0.1))

            if groupedTasks.isEmpty {
                VStack(spacing: 8) {
                    Text("No active tasks")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.gray)
                    Text("Press Esc and add a task")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedTasks, id: \.tier) { group in
                            // Section header
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(group.tier.color)
                                    .frame(width: 7, height: 7)

                                Text(group.tier.shortLabel)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(group.tier.color)

                                Text("\(group.tasks.count)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.5))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Capsule())

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 6)

                            // Task rows
                            ForEach(group.tasks) { task in
                                TaskRowView(
                                    task: task,
                                    isCompleted: completedTaskIds.contains(task.id)
                                ) {
                                    completeTask(task)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
            }

            Spacer(minLength: 4)

            Text("Esc to dismiss")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
        }
        .padding(.vertical, 4)
        .onKeyPress(.escape) {
            onBack()
            return .handled
        }
    }

    private func completeTask(_ task: StashTask) {
        // Mark as visually completed with animation
        withAnimation(.easeInOut(duration: 0.2)) {
            completedTaskIds.insert(task.id)
        }
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)

        // Actually complete in DB after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            appState.completeTask(task)
        }
    }
}

// MARK: - Task Row

struct TaskRowView: View {
    let task: StashTask
    let isCompleted: Bool
    let onComplete: () -> Void

    @State private var isHovered = false
    @State private var strikethroughWidth: CGFloat = 0

    var body: some View {
        HStack {
            ZStack(alignment: .leading) {
                Text(task.title)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(isCompleted ? .white.opacity(0.4) : .white.opacity(0.9))

                // Animated strikethrough line
                if isCompleted {
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0, anchor: .leading),
                            removal: .opacity
                        ))
                }
            }

            Spacer()

            Text(task.relativeTimeString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(isHovered && !isCompleted ? Color.white.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isCompleted else { return }
            onComplete()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .opacity(isCompleted ? 0.4 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isCompleted)
    }
}
