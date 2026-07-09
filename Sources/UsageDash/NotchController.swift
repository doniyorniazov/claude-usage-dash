import AppKit
import SwiftUI
import Combine

/// Drops a black "notch extension" panel out of the MacBook notch on demand.
/// Hidden by default. Shown via `toggle()` — typically the menu bar icon click.
@MainActor
final class NotchController: ObservableObject {
    @Published private(set) var isShowing: Bool = false
    @Published var contentVisible: Bool = false

    /// Notch corner radius in points. Match Apple's ~9–10pt rounded corners.
    static let notchCornerRadius: CGFloat = 9

    private weak var store: UsageStore?
    private var panel: NotchPanel?
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var subscriptions = Set<AnyCancellable>()

    private func dimensions(screen: NSScreen) -> (width: CGFloat, height: CGFloat) {
        let nw = notchWidth(screen)
        let mb = menuBarHeight(screen)
        let size = store?.notchSize ?? .standard
        let showsPlan = store?.notchShowPlan ?? false
        return (size.panelWidth(notchWidth: nw), size.panelHeight(menuBarHeight: mb, showsPlan: showsPlan))
    }

    var canShow: Bool { hasNotch(NSScreen.main) }

    deinit {
        if let m = clickMonitor { NSEvent.removeMonitor(m) }
        if let m = keyMonitor   { NSEvent.removeMonitor(m) }
        if let o = screenObserver { NotificationCenter.default.removeObserver(o) }
    }

    func bind(store: UsageStore) {
        self.store = store
        // Resize the panel live if the user changes size or plan toggle while it's open.
        store.$notchSize.dropFirst()
            .sink { [weak self] _ in self?.resizeIfShowing() }
            .store(in: &subscriptions)
        store.$notchShowPlan.dropFirst()
            .sink { [weak self] _ in self?.resizeIfShowing() }
            .store(in: &subscriptions)
    }

    private func resizeIfShowing() {
        guard isShowing, let screen = NSScreen.main else { return }
        let dims = dimensions(screen: screen)
        setFrame(width: dims.width, height: dims.height, screen: screen, animated: true, duration: 0.28)
    }

    /// Toggle visibility. Returns true if the action was a "show".
    @discardableResult
    func toggle() -> Bool {
        if isShowing { hide(); return false }
        show(); return true
    }

    func show() {
        guard let store, let screen = NSScreen.main, hasNotch(screen) else { return }
        ensurePanel(store: store, screen: screen)
        guard let panel else { return }

        // Reset state in case we're being shown right after a hide.
        panel.alphaValue = 1.0
        contentVisible = false

        // Pre-position at "just the notch with its rounded corners" — invisible.
        // Width must be ≥ notchWidth + 2*cornerRadius so the path stays geometrically
        // valid throughout the animation.
        let collapsed = collapsedDimensions(screen: screen)
        setFrame(width: collapsed.width, height: collapsed.height, screen: screen, animated: false)
        panel.orderFrontRegardless()
        isShowing = true

        // Expand the drop.
        let dims = dimensions(screen: screen)
        DispatchQueue.main.async {
            self.animateFrame(
                width: dims.width,
                height: dims.height,
                screen: screen,
                duration: 0.42,
                // "Drop settling" curve — quick descent, soft landing.
                timing: CAMediaTimingFunction(controlPoints: 0.20, 1.0, 0.30, 1.0)
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                self.contentVisible = true
            }
        }

        startMonitors()
    }

    func hide() {
        guard isShowing, let panel, let screen = NSScreen.main else { return }
        // Don't re-enter.
        isShowing = false
        stopMonitors()

        // 1. Fade the inner content out immediately (SwiftUI .transition handles the curve).
        contentVisible = false

        // 2. Retract the drop back into the notch AND fade the panel itself, in parallel.
        //    Using the panel's own alphaValue means the close looks clean even if the
        //    shape-rendering interpolation hiccups mid-animation.
        let collapsed = collapsedDimensions(screen: screen)
        animateFrame(
            width: collapsed.width,
            height: collapsed.height,
            screen: screen,
            duration: 0.30,
            // "Sucked back into notch" — easeIn (slow → fast) reads as acceleration upward.
            timing: CAMediaTimingFunction(name: .easeIn),
            alpha: 0.0
        ) { [weak panel] in
            panel?.orderOut(nil)
            panel?.alphaValue = 1.0   // reset for the next show
        }
    }

    private func collapsedDimensions(screen: NSScreen) -> (width: CGFloat, height: CGFloat) {
        let nw = notchWidth(screen)
        let mb = menuBarHeight(screen)
        // notchWidth + 2 * cornerRadius keeps the shape geometry valid at collapsed size.
        // Add the glow margin so the shape inside the padded view never collapses to 0.
        return (nw + 2 * Self.notchCornerRadius + 2 * NotchSize.glowMargin,
                mb + NotchSize.glowMargin)
    }

    // MARK: - Geometry

    private func hasNotch(_ screen: NSScreen?) -> Bool {
        (screen?.safeAreaInsets.top ?? 0) > 0
    }

    private func menuBarHeight(_ screen: NSScreen) -> CGFloat {
        screen.safeAreaInsets.top
    }

    private func notchWidth(_ screen: NSScreen) -> CGFloat {
        let l = screen.auxiliaryTopLeftArea?.width  ?? 0
        let r = screen.auxiliaryTopRightArea?.width ?? 0
        return max(160, screen.frame.width - l - r)
    }

    /// Compute the panel's frame anchored under the *actual* notch (not screen.midX —
    /// the notch can be a few pixels off-center when the menu bar auxiliary areas have
    /// unequal widths).
    private func frameForSize(width: CGFloat, height: CGFloat, screen: NSScreen) -> NSRect {
        let leftAreaWidth   = screen.auxiliaryTopLeftArea?.width  ?? 0
        let rightAreaWidth  = screen.auxiliaryTopRightArea?.width ?? 0
        let actualNotchWidth = screen.frame.width - leftAreaWidth - rightAreaWidth
        let notchCenterX = screen.frame.minX + leftAreaWidth + actualNotchWidth / 2
        return NSRect(
            x: notchCenterX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
    }

    /// Set frame instantly — no animation.
    private func setFrame(width: CGFloat, height: CGFloat, screen: NSScreen, animated: Bool, duration: CGFloat = 0.42) {
        guard let panel else { return }
        let frame = frameForSize(width: width, height: height, screen: screen)
        if animated {
            animateFrame(width: width, height: height, screen: screen, duration: duration,
                         timing: CAMediaTimingFunction(controlPoints: 0.20, 1.0, 0.30, 1.0))
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    /// Animate frame (and optionally alpha) with a real completion handler.
    private func animateFrame(width: CGFloat,
                              height: CGFloat,
                              screen: NSScreen,
                              duration: CGFloat,
                              timing: CAMediaTimingFunction,
                              alpha: CGFloat? = nil,
                              completion: (@MainActor () -> Void)? = nil) {
        guard let panel else { return }
        let frame = frameForSize(width: width, height: height, screen: screen)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            ctx.timingFunction = timing
            ctx.allowsImplicitAnimation = true
            panel.animator().setFrame(frame, display: true)
            if let alpha {
                panel.animator().alphaValue = alpha
            }
        }, completionHandler: {
            // completionHandler runs on the main thread but not on MainActor.
            Task { @MainActor in completion?() }
        })
    }

    // MARK: - Panel setup

    private func ensurePanel(store: UsageStore, screen: NSScreen) {
        if panel != nil { return }
        let mb = menuBarHeight(screen)
        let nw = notchWidth(screen)
        let panel = NotchPanel()
        let view = NotchView(
            store: store,
            controller: self,
            menuBarHeight: mb,
            notchWidth: nw
        )
        let host = NSHostingView(rootView: view)
        host.translatesAutoresizingMaskIntoConstraints = true
        panel.contentView = host
        self.panel = panel
    }

    // MARK: - Dismiss triggers

    private func startMonitors() {
        // Click anywhere outside our window → close.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            let weakSelf = self
            Task { @MainActor in weakSelf?.hide() }
        }
        // Esc → close.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                let weakSelf = self
                Task { @MainActor in weakSelf?.hide() }
                return nil
            }
            return event
        }
        // If the screen layout changes (display swap, dock/undock), retreat.
        if screenObserver == nil {
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                let weakSelf = self
                Task { @MainActor in weakSelf?.hide() }
            }
        }
    }

    private func stopMonitors() {
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
        if let m = keyMonitor   { NSEvent.removeMonitor(m); keyMonitor = nil }
    }
}
