import Foundation

enum NotchSize: String, CaseIterable, Identifiable {
    case compact, standard, spacious

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// Extra space around the visible shape so the neon glow shadow has room
    /// to bloom without being clipped at the window edge.
    static let glowMargin: CGFloat = 16

    /// Total flare past the notch (split equally between left and right wings).
    /// Drop width = notchWidth + sideFlare. Wider than before to fit the
    /// stacked time-remaining + reset-time column on the right of each row.
    var sideFlare: CGFloat {
        switch self {
        case .compact:  return 70
        case .standard: return 120
        case .spacious: return 200
        }
    }

    /// Panel width includes the visible drop + glow margin on each side.
    func panelWidth(notchWidth: CGFloat) -> CGFloat {
        notchWidth + sideFlare + 2 * Self.glowMargin
    }

    /// Panel height includes the visible drop + glow margin at the bottom only
    /// (the top must stay at y=0 so the notch cutout is exact). Each row is
    /// now two lines tall (time-remaining + reset clock/date below it).
    func panelHeight(menuBarHeight: CGFloat, showsPlan: Bool) -> CGFloat {
        let rows: CGFloat       = 60     // two 2-line rows + spacing
        let plan: CGFloat       = showsPlan ? 22 : 0
        let topInset: CGFloat   = 6
        let bottomPad: CGFloat  = 12
        let breathing: CGFloat
        switch self {
        case .compact:  breathing = 0
        case .standard: breathing = 6
        case .spacious: breathing = 18
        }
        return menuBarHeight + topInset + plan + rows + breathing + bottomPad + Self.glowMargin
    }
}
