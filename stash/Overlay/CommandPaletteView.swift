import SwiftUI

struct CommandPaletteView: View {
    @Binding var inputText: String
    let onSelect: (String) -> Void

    @State private var selectedIndex = 0

    private let allCommands: [(command: String, description: String)] = [
        ("/list", "View all tasks by tier"),
        ("/done", "View completed tasks"),
        ("/focus", "Open focus mode (L1 only)"),
        ("/snooze [task]", "Demote task one tier"),
        ("/promote [task]", "Promote task one tier"),
        ("/clear", "Clear completed tasks"),
        ("/settings", "Open settings"),
        ("/help", "Show all commands"),
    ]

    private var filteredCommands: [(command: String, description: String)] {
        let query = inputText.lowercased()
        if query == "/" { return allCommands }
        return allCommands.filter {
            $0.command.lowercased().hasPrefix(query) ||
            $0.command.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.08))

            ForEach(Array(filteredCommands.enumerated()), id: \.element.command) { index, cmd in
                HStack {
                    Text(cmd.command)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(index == selectedIndex ? .cyan : .white.opacity(0.8))

                    Spacer()

                    Text(cmd.description)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    index == selectedIndex
                        ? Color.white.opacity(0.08)
                        : Color.clear
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    let baseCmd = cmd.command.split(separator: " ").first.map(String.init) ?? cmd.command
                    onSelect(baseCmd)
                }
            }

            if filteredCommands.isEmpty {
                Text("No matching commands")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredCommands.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.return) {
            if !filteredCommands.isEmpty {
                let cmd = filteredCommands[selectedIndex]
                let baseCmd = cmd.command.split(separator: " ").first.map(String.init) ?? cmd.command
                onSelect(baseCmd)
            }
            return .handled
        }
        .onChange(of: inputText) { _, _ in
            selectedIndex = 0
        }
    }
}
