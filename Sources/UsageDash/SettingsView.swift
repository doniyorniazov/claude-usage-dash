import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        Form {
            Section("Notch panel") {
                Toggle("Show notch drop (notched MacBooks)", isOn: $store.notchModeEnabled)
                Picker("Drop size", selection: $store.notchSize) {
                    ForEach(NotchSize.allCases) { size in
                        Text(size.label).tag(size)
                    }
                }
                .disabled(!store.notchModeEnabled)
                Toggle("Show plan name", isOn: $store.notchShowPlan)
                    .disabled(!store.notchModeEnabled)
            }
            Section("Refresh") {
                Picker("Probe interval", selection: $store.refreshIntervalSeconds) {
                    Text("1 minute").tag(60.0)
                    Text("5 minutes").tag(300.0)
                    Text("15 minutes").tag(900.0)
                    Text("30 minutes").tag(1800.0)
                }
            }
            Section {
                Text("Each probe sends a 1-token message to Claude Haiku (≈ $0.00001) and reads the live rate-limit headers Anthropic returns.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 360)
    }
}
