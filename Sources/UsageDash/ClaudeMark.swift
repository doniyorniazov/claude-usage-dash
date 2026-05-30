import SwiftUI

/// Stylized 8-petal starburst that evokes Claude's brand mark.
/// Drawn from scratch so we don't ship any official asset.
struct ClaudeMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let petalCount = 8

        for i in 0..<petalCount {
            let angle = Double(i) * 2 * .pi / Double(petalCount)
            // Long petals (cardinals at 0,2,4,6) get full length; diagonals 70%.
            let isLong = (i % 2 == 0)
            let length = radius * (isLong ? 1.0 : 0.72)
            let halfWidth = radius * (isLong ? 0.18 : 0.13)

            var petal = Path()
            // A leaf/lens: tip at origin, base at +length on the x-axis.
            petal.move(to: .zero)
            petal.addQuadCurve(
                to: CGPoint(x: length, y: 0),
                control: CGPoint(x: length * 0.45, y: halfWidth)
            )
            petal.addQuadCurve(
                to: .zero,
                control: CGPoint(x: length * 0.45, y: -halfWidth)
            )

            let t = CGAffineTransform.identity
                .translatedBy(x: center.x, y: center.y)
                .rotated(by: angle)
            path.addPath(petal.applying(t))
        }
        return path
    }
}
