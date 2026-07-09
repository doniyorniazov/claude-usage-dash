import AppKit

/// Floating panel that lives at `.statusBar` level and never steals focus.
/// We use NSPanel so it can hover above other apps without activating UsageDash.
final class NotchPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 24),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        hasShadow = false
        backgroundColor = .clear
        isOpaque = false
        hidesOnDeactivate = false
        worksWhenModal = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        animationBehavior = .none
        isMovable = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
