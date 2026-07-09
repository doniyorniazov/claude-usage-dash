import SwiftUI

@main
struct UsageDashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            SettingsView(store: delegate.store)
        }
    }

    /// Menu bar icon image. Prefers a bundled `ClaudeIcon.png` (drop one into
    /// Sources/UsageDash/Resources/ and rebuild) and falls back to the
    /// drawn ClaudeMark rendered as a template — white in dark menu bars,
    /// black in light ones, like every other menu-bar icon.
    @MainActor
    static let claudeMarkImage: NSImage = {
        let size: CGFloat = 18

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
                .fill(.black)
                .frame(width: size, height: size)
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let img = renderer.nsImage ?? NSImage(size: NSSize(width: size, height: size))
        img.isTemplate = true
        return img
    }()
}
