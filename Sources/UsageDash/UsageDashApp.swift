import SwiftUI

@main
struct UsageDashApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
        } label: {
            menuLabel
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store)
        }
    }

    @ViewBuilder
    private var menuLabel: some View {
        let pct = store.state.representativeUtilization
        HStack(spacing: 4) {
            Image(nsImage: Self.claudeMarkImage)
            Text(Fmt.percent(pct))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(pct >= 1.0 ? Color.red : .primary)
        }
        .onAppear { store.start() }
    }

    /// Menu bar icon. Prefers a bundled `ClaudeIcon.png` (drop one into
    /// Sources/UsageDash/Resources/ and rebuild) and falls back to the
    /// drawn ClaudeMark rendered as a template — white in dark menu bars,
    /// black in light ones, like every other menu-bar icon.
    @MainActor
    private static let claudeMarkImage: NSImage = {
        let size: CGFloat = 18

        // Bundle.main wins (loose Contents/Resources/ClaudeIcon.png), then SPM bundle for `swift run`.
        for bundle in [Bundle.main, Bundle.module] {
            if let url = bundle.url(forResource: "ClaudeIcon", withExtension: "png"),
               let img = NSImage(contentsOf: url) {
                img.size = NSSize(width: size, height: size)
                img.isTemplate = true
                return img
            }
        }

        let renderer = ImageRenderer(content:
            ClaudeMark()
                .fill(.black)  // any opaque color works; template draws as foreground
                .frame(width: size, height: size)
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let img = renderer.nsImage ?? NSImage(size: NSSize(width: size, height: size))
        img.isTemplate = true
        return img
    }()
}
