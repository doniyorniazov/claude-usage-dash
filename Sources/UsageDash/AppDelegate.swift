import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let store = UsageStore()
    let notch = NotchController()

    private var statusItem: NSStatusItem!
    private var fallbackPopover: NSPopover!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItem()
        configureFallbackPopover()
        notch.bind(store: store)
        store.start()
    }

    // MARK: - Status item

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = UsageDashApp.claudeMarkImage
        button.imagePosition = .imageLeft
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
        button.action = #selector(statusItemClicked(_:))

        // Live label updates.
        store.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.refreshButtonTitle(state.representativeUtilization)
            }
            .store(in: &cancellables)
        refreshButtonTitle(0)
    }

    private func refreshButtonTitle(_ pct: Double) {
        statusItem.button?.title = " " + Fmt.percent(pct)
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp ||
            (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true)
        if isRightClick {
            showContextMenu()
            return
        }
        if store.notchModeEnabled && notch.canShow {
            // Toggle the notch drop.
            if fallbackPopover.isShown { fallbackPopover.performClose(nil) }
            notch.toggle()
        } else {
            // No notch (or feature off) — show the traditional popover instead.
            if notch.isShowing { notch.hide() }
            toggleFallbackPopover()
        }
    }

    // MARK: - Fallback popover (non-notched displays)

    private func configureFallbackPopover() {
        fallbackPopover = NSPopover()
        fallbackPopover.behavior = .transient
        fallbackPopover.animates = true
        fallbackPopover.contentViewController = NSHostingController(rootView: PopoverView(store: store))
    }

    private func toggleFallbackPopover() {
        guard let button = statusItem.button else { return }
        if fallbackPopover.isShown {
            fallbackPopover.performClose(nil)
        } else {
            fallbackPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Right-click menu

    private func showContextMenu() {
        let menu = NSMenu()

        let toggleTitle = store.notchModeEnabled ? "Disable notch drop" : "Enable notch drop"
        addItem(to: menu, title: toggleTitle, action: #selector(toggleNotchMode))
        addItem(to: menu, title: "Refresh now", action: #selector(refreshNow), key: "r")
        menu.addItem(.separator())
        addItem(to: menu, title: "Settings…", action: #selector(openSettings), key: ",")
        menu.addItem(.separator())
        addItem(to: menu, title: "Quit UsageDash", action: #selector(quit), key: "q")

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil   // detach so left-click goes back to our action
    }

    private func addItem(to menu: NSMenu, title: String, action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    @objc private func toggleNotchMode() { store.notchModeEnabled.toggle() }
    @objc private func refreshNow() { store.refresh() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        // macOS 14+: standard Settings menu action.
        let showSettings = Selector(("showSettingsWindow:"))
        if NSApp.responds(to: showSettings) {
            NSApp.sendAction(showSettings, to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
