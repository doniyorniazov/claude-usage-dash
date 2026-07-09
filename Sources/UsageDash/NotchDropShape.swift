import SwiftUI

/// Just the side + bottom outline of the drop. The TOP edge is intentionally
/// omitted so the neon stroke draws only the left side, the bottom (rounded),
/// and the right side — never across the top where the notch lives.
struct NotchDropOuterShape: Shape {
    var bottomRadius: CGFloat

    nonisolated var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let dr = min(bottomRadius, rect.width / 2, max(0, rect.height) / 2)
        var p = Path()
        // Start at top-right corner — note: no top edge, just travel down.
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - dr))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - dr, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        p.addLine(to: CGPoint(x: rect.minX + dr, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - dr),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        // End at top-left corner. No closeSubpath — leaves the top edge open.
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        return p
    }
}

/// Rectangle with the notch carved out of its top, plus rounded bottom corners.
/// Result: when the drop is shown, the notch reads as having widened — the
/// black mass extends past the notch on both sides at menu-bar level, and
/// continues straight down into the usage area.
struct NotchDropShape: Shape {
    var notchWidth: CGFloat
    var menuBarHeight: CGFloat
    var notchCornerRadius: CGFloat = 9       // matches Apple's notch corner ~9–10 pt
    var dropBottomRadius: CGFloat = 22

    nonisolated var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(notchWidth, menuBarHeight) }
        set { notchWidth = newValue.first; menuBarHeight = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let mid    = rect.midX
        let r      = notchCornerRadius
        // The notchWidth we receive (from auxiliaryTopLeftArea/RightArea) measures
        // to the OUTER extent of the notch — including the bottom corner flare.
        // The notch's vertical edges are narrower than that by exactly `r` on each
        // side. Use that inner width for the hole so the black covers the menu bar
        // all the way up to the actual notch boundary at every Y, with no gap.
        let innerHalf = max(0, notchWidth / 2 - r)
        let nLeft  = mid - innerHalf
        let nRight = mid + innerHalf

        // Clamp bottom radius to whatever the rect can accommodate (handles
        // intermediate animation frames where the panel hasn't grown yet).
        let dropArea = max(0, rect.maxY - menuBarHeight)
        let dr       = min(dropBottomRadius, rect.width / 2, dropArea / 2)

        let dropLeft  = rect.minX
        let dropRight = rect.maxX
        let bottomY   = rect.maxY
        let topY      = rect.minY

        var p = Path()

        // ── Outer rectangle (clockwise) ─────────────────────────────────────
        p.move(to: CGPoint(x: dropLeft, y: topY))
        p.addLine(to: CGPoint(x: dropRight, y: topY))
        p.addLine(to: CGPoint(x: dropRight, y: bottomY - dr))
        p.addQuadCurve(
            to: CGPoint(x: dropRight - dr, y: bottomY),
            control: CGPoint(x: dropRight, y: bottomY)
        )
        p.addLine(to: CGPoint(x: dropLeft + dr, y: bottomY))
        p.addQuadCurve(
            to: CGPoint(x: dropLeft, y: bottomY - dr),
            control: CGPoint(x: dropLeft, y: bottomY)
        )
        p.closeSubpath()

        // ── Notch hole (rectangular, sharp corners) ────────────────────────
        // Sharp 90° corners cover the hardware notch's rounded screen-pixel
        // sliver with black, so visually the notch reads as boxy with no
        // rounded transition. Counter-clockwise winding cuts it out.
        _ = r   // kept on the struct for animatableData / fill-symmetry only
        p.move(to: CGPoint(x: nLeft, y: topY))
        p.addLine(to: CGPoint(x: nLeft, y: menuBarHeight))
        p.addLine(to: CGPoint(x: nRight, y: menuBarHeight))
        p.addLine(to: CGPoint(x: nRight, y: topY))
        p.closeSubpath()

        return p
    }
}
