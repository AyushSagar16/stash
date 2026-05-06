import SwiftUI

struct TaskRowView: View {
    let task: StashTask
    let isSelected: Bool
    let onComplete: () -> Void

    @State private var isHovered = false
    @State private var isCompleting = false

    /// Delay between the checkmark animation starting and the actual model mutation.
    /// Long enough for the user to register the visual feedback, short enough that
    /// the row doesn't linger.
    private static let completionFlashDuration: Double = 0.28

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(Palette.tierColor(task.tier))
                .frame(width: 6, height: 6)
                .alignmentGuide(.firstTextBaseline) { d in d.height - 1 }
                .opacity(isCompleting ? 0.35 : 1)

            Text(task.id)
                .font(Palette.idFont)
                .foregroundStyle(Palette.idColor)
                .frame(width: 30, alignment: .leading)
                .opacity(isCompleting ? 0.35 : 1)

            Text(task.title)
                .font(Palette.titleFont)
                .foregroundStyle(isCompleting ? .secondary : .primary)
                .strikethrough(task.status == .done || isCompleting, color: .secondary)
                .lineLimit(1)

            if !task.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(task.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(Palette.metaFont)
                            .foregroundStyle(.tertiary)
                    }
                }
                .opacity(isCompleting ? 0.35 : 1)
            }

            Spacer(minLength: 8)

            if isOverdue && !isCompleting {
                Text("overdue")
                    .font(Palette.metaFont)
                    .foregroundStyle(Palette.overdueColor)
            }

            // Checkbox: hidden until hover, fills+flashes green during the
            // completion animation. The fill scales up briefly for tactile feedback.
            Image(systemName: isCompleting ? "checkmark.square.fill" : "square")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(isCompleting ? Color.green : .secondary)
                .scaleEffect(isCompleting ? 1.18 : 1.0)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
                .opacity(isCompleting ? 1 : (isHovered ? 0.75 : 0))
                .allowsHitTesting(isHovered && !isCompleting)
                .onTapGesture { triggerCompletion() }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(rowBackground)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isCompleting)
        .transition(.asymmetric(
            insertion: .opacity,
            removal: .opacity.combined(with: .move(edge: .leading))
        ))
    }

    private func triggerCompletion() {
        guard !isCompleting else { return }
        isCompleting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.completionFlashDuration) {
            onComplete()
        }
    }

    private var rowBackground: Color {
        if isSelected { return Palette.selectionColor }
        if isHovered { return Palette.rowHoverColor }
        return .clear
    }

    private var isOverdue: Bool {
        guard task.status == .open, let due = task.dueAt else { return false }
        return Date.now > due
    }
}
