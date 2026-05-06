import SwiftUI

struct TierSectionView: View {
    let tier: Tier
    let tasks: [StashTask]
    let selectedTaskID: String?
    let onComplete: (StashTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Palette.tierColor(tier))
                    .frame(width: 5, height: 5)
                Text(tier.label.uppercased())
                    .font(Palette.sectionFont)
                    .foregroundStyle(Palette.sectionColor)
                    .tracking(0.6)
            }
            .padding(.horizontal, 6)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(tasks, id: \.id) { task in
                    TaskRowView(
                        task: task,
                        isSelected: task.id == selectedTaskID,
                        onComplete: { onComplete(task) }
                    )
                }
            }
        }
    }
}
