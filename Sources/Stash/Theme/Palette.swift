import SwiftUI

enum Palette {
    // Typography
    static let inputFont    = Font.system(size: 16, weight: .regular, design: .monospaced)
    static let promptFont   = Font.system(size: 17, weight: .light,    design: .monospaced)
    static let idFont       = Font.system(size: 12, weight: .regular,  design: .monospaced)
    static let titleFont    = Font.system(size: 13, weight: .regular)
    static let sectionFont  = Font.system(size: 10, weight: .medium)
    static let metaFont     = Font.system(size: 10, weight: .regular,  design: .monospaced)

    // Geometry
    static let cornerRadius:   CGFloat = 8
    static let panelWidth:     CGFloat = 540
    static let panelMaxHeight: CGFloat = 420  // Cap for the scrolling task area.
    static let inputHeight:    CGFloat = 48
    static let rowHoverColor   = Color.primary.opacity(0.06)

    // Colors (system-adaptive: primary/secondary/tertiary auto-flip in dark mode)
    static let promptColor       = Color.secondary
    static let placeholderColor  = Color.secondary.opacity(0.5)
    static let inputColor        = Color.primary
    static let idColor           = Color.secondary
    static let sectionColor      = Color.secondary.opacity(0.8)
    static let overdueColor      = Color.red
    static let ghostColor        = Color.secondary.opacity(0.45)
    static let selectionColor    = Color.accentColor.opacity(0.18)

    static func tierColor(_ tier: Tier) -> Color {
        switch tier {
        case .L1: .red
        case .L2: .yellow
        case .L3: .green
        }
    }
}
