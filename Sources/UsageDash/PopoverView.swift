import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: UsageStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            limitRow(
                title: "Current session",
                subtitle: "Resets in \(Fmt.timeUntil(store.state.sessionResetAt))",
                pct: store.state.sessionUtilization
            )
            limitRow(
                title: "Weekly (7-day)",
                subtitle: "Resets in \(Fmt.timeUntil(store.state.weeklyResetAt))",
                pct: store.state.weeklyUtilization
            )
            if let err = store.lastError {
                Divider()
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 320)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude Usage")
                    .font(.headline)
                if let plan = store.plan {
                    Text(plan.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if store.isRefreshing {
                ProgressView().controlSize(.small)
            } else if store.state.fetchedAt != .distantPast {
                Text(store.state.fetchedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func limitRow(title: String, subtitle: String, pct: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(Fmt.percent(pct))
                    .font(.subheadline)
                    .foregroundStyle(color(for: pct))
                    .monospacedDigit()
            }
            ProgressView(value: min(pct, 1.0))
                .tint(Color.claudeOrange)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            Button { store.refresh() } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            Spacer()
            Button {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            Button { NSApp.terminate(nil) } label: {
                Label("Quit", systemImage: "power")
            }
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }

    private func color(for pct: Double) -> Color {
        // Tint the % text Claude-orange normally, switching to red once we cross the limit
        // so the warning still reads at a glance.
        pct >= 1.0 ? .red : .claudeOrange
    }

}

extension Color {
    /// Claude's brand coral-orange (#D97757).
    static let claudeOrange = Color(red: 217/255, green: 119/255, blue: 87/255)
}
