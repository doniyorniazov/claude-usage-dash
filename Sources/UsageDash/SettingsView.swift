import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        Form {
            Section("Refresh") {
                Picker("Probe interval", selection: $store.refreshIntervalSeconds) {
                    Text("1 minute").tag(60.0)
                    Text("5 minutes").tag(300.0)
                    Text("15 minutes").tag(900.0)
                    Text("30 minutes").tag(1800.0)
                }
            }
            Section {
                Text("Each probe sends a 1-token message to Claude Haiku (≈ $0.00001) and reads the live rate-limit headers Anthropic returns. There is no dedicated read-only endpoint.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 220)
    }
}
