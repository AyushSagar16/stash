import SwiftUI

struct TaskRowView: View {
    let task: StashTask
    let isSelected: Bool
    let onComplete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(Palette.tierColor(task.tier))
                .frame(width: 6, height: 6)
                .alignmentGuide(.firstTextBaseline) { d in d.height - 1 }

            Text(task.id)
                .font(Palette.idFont)
                .foregroundStyle(Palette.idColor)
                .frame(width: 30, alignment: .leading)

            Text(task.title)
                .font(Palette.titleFont)
                .foregroundStyle(.primary)
                .strikethrough(task.status == .done, color: .secondary)
                .lineLimit(1)

            if !task.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(task.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(Palette.metaFont)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 8)

            if isOverdue {
                Text("overdue")
                    .font(Palette.metaFont)
                    .foregroundStyle(Palette.overdueColor)
            }

            // Checkbox: always rendered (no layout shift on hover) but only visible
            // and clickable while the row is hovered.
            Image(systemName: "square")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
                .opacity(isHovered ? 0.75 : 0)
                .allowsHitTesting(isHovered)
                .onTapGesture { onComplete() }
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
