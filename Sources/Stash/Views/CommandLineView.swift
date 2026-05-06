import SwiftUI

enum InputMode {
    case add, complete
}

struct CommandLineView: View {
    @Binding var input: String
    @Binding var hint: String
    @FocusState.Binding var focused: Bool

    let mode: InputMode
    let pendingTier: Tier
    let suggestion: Suggestion?

    let onSubmit: () -> Void
    let onTab: () -> Void          // cycle severity (add mode only)
    let onShiftTab: () -> Void     // toggle add ↔ complete
    let onAcceptSuggestion: () -> Void
    let onArrowUp: () -> Void
    let onArrowDown: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("›")
                .font(Palette.promptFont)
                .foregroundStyle(Palette.promptColor)

            inputField
                .frame(maxWidth: .infinity, alignment: .leading)

            if let suggestion {
                Text(suggestion.kindLabel)
                    .font(Palette.metaFont)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .layoutPriority(-1)
            }

            if !hint.isEmpty {
                Text(hint)
                    .font(Palette.metaFont)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .layoutPriority(-2)
            }

            if mode == .add {
                pendingTierChip
            }

            modeChip
        }
        .padding(.horizontal, 18)
        .frame(height: Palette.inputHeight)
        .animation(.easeInOut(duration: 0.15), value: mode)
        .animation(.easeInOut(duration: 0.15), value: pendingTier)
    }

    // MARK: - Input field with ghost-text overlay

    private var inputField: some View {
        ZStack(alignment: .leading) {
            if input.isEmpty && mode == .add {
                Text("type a task…")
                    .font(Palette.inputFont)
                    .foregroundStyle(Palette.placeholderColor)
            }

            // Ghost text: hidden copy of `input` reserves the same width as the
            // visible text in the field, then the suggestion remainder shows after it.
            if let remainder = ghostRemainder, !remainder.isEmpty {
                HStack(spacing: 0) {
                    Text(input)
                        .font(Palette.inputFont)
                        .opacity(0)
                    Text(remainder)
                        .font(Palette.inputFont)
                        .foregroundStyle(Palette.ghostColor)
                }
                .allowsHitTesting(false)
            }

            TextField("", text: $input)
                .textFieldStyle(.plain)
                .font(Palette.inputFont)
                .foregroundStyle(mode == .add ? Palette.inputColor : Palette.inputColor.opacity(0.4))
                .focused($focused)
                .onKeyPress(.tab) {
                    onTab()
                    return .handled
                }
                // macOS routes Shift+Tab as the back-tab character (\u{19}), not Tab+shift.
                .onKeyPress(KeyEquivalent("\u{19}")) {
                    onShiftTab()
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    onArrowUp()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    onArrowDown()
                    return .handled
                }
                .onKeyPress(.rightArrow) {
                    if suggestion != nil && mode == .add {
                        onAcceptSuggestion()
                        return .handled
                    }
                    return .ignored
                }
                .onSubmit(onSubmit)
        }
    }

    private var ghostRemainder: String? {
        guard mode == .add, let suggestion else { return nil }
        let full = suggestion.fullText
        guard full.hasPrefix(input) else { return nil }
        return String(full.dropFirst(input.count))
    }

    // MARK: - Chips

    private var pendingTierChip: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Palette.tierColor(pendingTier))
                .frame(width: 6, height: 6)
            Text(pendingTier.rawValue)
                .font(Palette.metaFont)
                .foregroundStyle(Palette.tierColor(pendingTier))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Palette.tierColor(pendingTier).opacity(0.12))
        )
    }

    private var modeChip: some View {
        let label = mode == .add ? "ADD" : "DONE"
        let color: Color = mode == .add ? .red : .green
        return Text(label)
            .font(Palette.metaFont)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.opacity(0.12))
            )
    }
}
