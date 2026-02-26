import SwiftUI

enum OverlayMode {
    case input
    case list
    case done
    case help
}

struct OverlayView: View {
    @ObservedObject var appState: AppState
    let onDismiss: () -> Void
    let onFocusMode: () -> Void
    let onSettings: () -> Void
    let onResizePanel: (CGFloat) -> Void

    @State private var isVisible = false

    private let inputPanelHeight: CGFloat = 280
    private let listPanelHeight: CGFloat = 460
    private let helpPanelHeight: CGFloat = 380

    private var mode: OverlayMode {
        appState.overlayMode
    }

    var body: some View {
        VStack(spacing: 0) {
            switch mode {
            case .input:
                CommandInputView(
                    appState: appState,
                    onDismiss: onDismiss,
                    onSwitchMode: { newMode in
                        withAnimation(.easeInOut(duration: 0.12)) {
                            appState.overlayMode = newMode
                        }
                        // Resize panel based on mode
                        switch newMode {
                        case .list, .done:
                            onResizePanel(listPanelHeight)
                        case .help:
                            onResizePanel(helpPanelHeight)
                        case .input:
                            onResizePanel(inputPanelHeight)
                        }
                    },
                    onFocusMode: onFocusMode,
                    onSettings: onSettings
                )

            case .list:
                TaskListView(appState: appState) {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        appState.overlayMode = .input
                    }
                    onResizePanel(inputPanelHeight)
                }

            case .done:
                DoneListView(appState: appState) {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        appState.overlayMode = .input
                    }
                    onResizePanel(inputPanelHeight)
                }

            case .help:
                HelpView {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        appState.overlayMode = .input
                    }
                    onResizePanel(inputPanelHeight)
                }
            }
        }
        .frame(width: 520)
        .background(
            VisualEffectBlur()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .scaleEffect(isVisible ? 1.0 : 0.92)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.8)) {
                isVisible = true
            }
            appState.reload()
        }
    }
}

// MARK: - Help View

struct HelpView: View {
    let onBack: () -> Void

    private let commands: [(String, String)] = [
        ("/list", "View all active tasks by tier"),
        ("/done", "View completed tasks"),
        ("/focus", "Open L1 focus strip"),
        ("/snooze [task]", "Demote task down one tier"),
        ("/promote [task]", "Promote task up one tier"),
        ("/clear", "Clear all completed tasks"),
        ("/settings", "Open settings panel"),
        ("/help", "Show this help"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Commands")
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

            Divider().background(Color.white.opacity(0.1))

            ForEach(commands, id: \.0) { cmd, desc in
                HStack {
                    Text(cmd)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.cyan)
                    Spacer()
                    Text(desc)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }

            Spacer(minLength: 8)

            Text("Press Esc to dismiss")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Done List View

struct DoneListView: View {
    @ObservedObject var appState: AppState
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Completed Tasks")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
                if !appState.completedTasks.isEmpty {
                    Button(action: {
                        appState.clearCompleted()
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                    }) {
                        Text("clear all")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                Button(action: onBack) {
                    Text("← back")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Divider().background(Color.white.opacity(0.1))

            if appState.completedTasks.isEmpty {
                Text("No completed tasks")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(appState.completedTasks) { task in
                            HStack {
                                Text(task.title)
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.4))
                                    .strikethrough(true, color: .white.opacity(0.3))
                                Spacer()
                                Text(task.relativeTimeString)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                        }
                    }
                }
                .frame(maxHeight: 350)
            }

            Spacer(minLength: 8)

            Text("Esc to dismiss")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.gray.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
        }
        .padding(.vertical, 4)
        .onAppear {
            appState.reloadCompleted()
        }
    }
}

// MARK: - Visual Effect Blur

struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 16
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
