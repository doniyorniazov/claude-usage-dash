import SwiftUI

/// The drop's SwiftUI content. The black shape extends from the very top of
/// the screen (covering menu-bar pixels around the notch) down to its rounded
/// bottom. The notch is a cutout in the top; the usage rows sit below it.
struct NotchView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var controller: NotchController
    let menuBarHeight: CGFloat
    let notchWidth: CGFloat

    private static let bottomRadius: CGFloat = 22

    private var fillShape: NotchDropShape {
        NotchDropShape(
            notchWidth: notchWidth,
            menuBarHeight: menuBarHeight,
            notchCornerRadius: NotchController.notchCornerRadius,
            dropBottomRadius: Self.bottomRadius
        )
    }

    private var outerShape: NotchDropOuterShape {
        NotchDropOuterShape(bottomRadius: Self.bottomRadius)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Fill — full shape with the notch as a hole so the cutout stays transparent.
            fillShape
                .fill(.black)
                .shadow(color: .black.opacity(0.35), radius: 14, y: 8)

            // Neon outline — left + bottom + right only (no top edge, no notch outline).
            outerShape
                .stroke(Color.claudeOrange, lineWidth: 1.6)
                .shadow(color: Color.claudeOrange.opacity(0.9), radius: 2)
                .shadow(color: Color.claudeOrange.opacity(0.55), radius: 6)
                .shadow(color: Color.claudeOrange.opacity(0.3), radius: 12)

            VStack(spacing: 0) {
                Color.clear.frame(height: menuBarHeight + 4)
                if controller.contentVisible {
                    NotchUsageView(store: store)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top))
                                .animation(.easeOut(duration: 0.22).delay(0.12)),
                            removal:   .opacity.combined(with: .move(edge: .top))
                                .animation(.easeOut(duration: 0.16))
                        ))
                }
                Spacer(minLength: 0)
            }
        }
        // Inset the rendered shape so the neon shadow has room to spread —
        // top stays flush at y=0 so the notch cutout aligns exactly.
        .padding(.leading,  NotchSize.glowMargin)
        .padding(.trailing, NotchSize.glowMargin)
        .padding(.bottom,   NotchSize.glowMargin)
        // Critical: bypass SwiftUI's automatic safe-area inset at the top so
        // the shape extends behind the menu bar / notch and there's no gap.
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
}

/// Stacked D / W rows. Right side of each row shows time-remaining (top)
/// and the actual reset moment (bottom) — e.g. "2h 3m / 5:30PM" or
/// "3d 18h / Tue, Jun 2".
struct NotchUsageView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.notchShowPlan, let plan = store.plan {
                Text(plan.displayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            row(
                label: "D",
                pct: store.state.sessionUtilization,
                resetAt: store.state.sessionResetAt,
                resetLabel: Fmt.clockTime(store.state.sessionResetAt)
            )
            row(
                label: "W",
                pct: store.state.weeklyUtilization,
                resetAt: store.state.weeklyResetAt,
                resetLabel: Fmt.weekdayDate(store.state.weeklyResetAt)
            )
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }

    private func row(label: String, pct: Double, resetAt: Date?, resetLabel: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 14, alignment: .leading)
            ProgressView(value: min(pct, 1.0))
                .tint(Color.claudeOrange)
                .progressViewStyle(.linear)
            VStack(alignment: .trailing, spacing: 1) {
                Text(Fmt.timeUntil(resetAt))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(pct >= 1.0 ? .red : .white)
                Text(resetLabel)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
        }
    }
}
