import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var appState: AppState

    @AppStorage("escalationEnabled") private var escalationEnabled = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    @State private var showClearConfirmation = false
    @State private var exportMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                Text("Stash Settings")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)

                Divider()

                // Hotkey
                settingsSection(title: "Hotkey") {
                    HStack {
                        Text("Global Shortcut")
                            .font(.system(size: 13))
                        Spacer()
                        Text("⌥ Space")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(6)
                    }
                }

                Divider()

                // Escalation
                settingsSection(title: "Escalation") {
                    Toggle("Auto-escalation", isOn: $escalationEnabled)
                        .font(.system(size: 13))

                    if escalationEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("L2 → L1: after 2 hours (if L1 < 3 tasks)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text("L3 → L2: after 5 hours (if L2 < 3 tasks)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text("MEM: never auto-escalates")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }

                Divider()

                // Notifications
                settingsSection(title: "Notifications") {
                    Toggle("Escalation notifications", isOn: $notificationsEnabled)
                        .font(.system(size: 13))
                }

                Divider()

                // Appearance
                settingsSection(title: "Appearance") {
                    Picker("Theme", selection: $appearanceMode) {
                        Text("System").tag("system")
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 250)
                }

                Divider()

                // Launch at Login
                settingsSection(title: "General") {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .font(.system(size: 13))
                }

                Divider()

                // Data
                settingsSection(title: "Data") {
                    HStack(spacing: 12) {
                        Button("Export as JSON") {
                            exportTasks()
                        }
                        .buttonStyle(.bordered)

                        Button("Clear All Data") {
                            showClearConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }

                    if let msg = exportMessage {
                        Text(msg)
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(24)
        }
        .frame(width: 400, height: 500)
        .alert("Clear All Data", isPresented: $showClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                appState.clearAllData()
            }
        } message: {
            Text("This will permanently delete all tasks. This cannot be undone.")
        }
    }

    @ViewBuilder
    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func exportTasks() {
        guard let json = DatabaseManager.shared.exportJSON() else {
            exportMessage = "Export failed"
            return
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "stash-tasks.json"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try json.write(to: url, atomically: true, encoding: .utf8)
                exportMessage = "Exported successfully!"
            } catch {
                exportMessage = "Failed to save: \(error.localizedDescription)"
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            exportMessage = nil
        }
    }
}
