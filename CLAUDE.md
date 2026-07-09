# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

UsageDash is a macOS menu bar agent (LSUIElement, no dock icon) that displays live Claude rate-limit usage. Pure Swift/SwiftUI, single SPM executable target, macOS 14+. ~350 lines of source under `Sources/UsageDash/`.

## Build & run

```
./build.sh              # release build → UsageDash.app + dist/UsageDash-v0.1.0.zip
./build.sh 0.7.0        # explicit version (drives Info.plist + zip name)
swift build             # debug build (no .app bundle, no Info.plist)
swift build -c release  # what build.sh wraps; emits binary into .build/release
open UsageDash.app      # run after build.sh
```

There is no test target, no linter, and no Xcode project — just `Package.swift`. Full Xcode is not required; Xcode Command Line Tools are enough.

Releases are cut by pushing a `v*` tag — `.github/workflows/release.yml` runs `./build.sh` on `macos-15`, ad-hoc signs, and attaches the zip to a GitHub Release.

## How the app is wired together

**Entry point.** `UsageDashApp.swift` is `@main` but does almost nothing — it hosts an empty `Settings` scene and an `NSApplicationDelegateAdaptor`. The real wiring lives in `AppDelegate.swift`:

- Creates the `NSStatusItem` (menu bar icon + percentage label).
- Owns one `UsageStore` (observable state) and one `NotchController` (the drop-out-of-the-notch panel).
- Left-click → toggles either the notch drop (if the display has a notch and the user has it enabled) or a fallback `NSPopover`. Right-click → context menu.

**State + polling.** `UsageStore` is the single `@MainActor` source of truth. It holds the latest `LimitState`, `PlanInfo`, and user preferences, persists prefs to `UserDefaults`, and runs a repeating `Timer` that calls `UsageProbe.fetch()` every N seconds (default 300). The status item label and all UI subscribe via Combine.

**Probing.** `UsageProbe.fetch()` POSTs a 1-token Haiku message to `https://api.anthropic.com/v1/messages` and reads the `anthropic-ratelimit-unified-*` response headers (5h + 7d utilization + reset epoch, plus overage status). `ProfileFetcher` GETs `/api/oauth/profile` once at launch to learn the plan tier. Both authenticate by reading the `Claude Code-credentials` Keychain item (`Keychain.swift`) — same OAuth token the `claude` CLI uses. **There is no API key; the app cannot work unless Claude Code has been signed in on this machine.**

**Notch drop.** `NotchController` + `NotchPanel` + `NotchView` + `NotchDropShape` + `NotchSize` implement an `NSPanel` that animates down from under the MacBook notch. The panel is anchored to the *actual* notch center (computed from `screen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea`, not `screen.midX` — they can be unequal), and `hasNotch` is gated on `screen.safeAreaInsets.top > 0`. On non-notched displays the controller short-circuits and the fallback `NSPopover` is used instead.

## Things to know before editing

- **Swift 6 strict concurrency is on.** The codebase is heavily `@MainActor`. When capturing `self` inside `Task { @MainActor in … }` from a closure, capture into a local `let` first — see `UsageStore.restartTimer()` and the monitor blocks in `NotchController` for the pattern (the last CI fix was specifically about this).
- **Probing costs real tokens.** Every probe is a billed API call (≈8 input + 1 output token on Haiku). Don't lower the default interval below 60s, and don't add UI that fires probes on user interaction without rate-limiting — `UsageStore.refresh()` guards against re-entry with `isRefreshing`.
- **Both 200 and 429 carry the rate-limit headers**; 401 means re-auth. `UsageProbe.parseHeaders` is the source of truth for what counts as a usable response.
- **Resources live in `Sources/UsageDash/Resources/`** and are loaded via `Bundle.main` *and* `Bundle.module` (the SPM resource bundle) — keep both lookups when adding assets, because `build.sh` flattens resources into `Contents/Resources/` of the `.app` so `Bundle.main` finds them at runtime, while `swift run` only sees them via `Bundle.module`.
- **Menu bar icon is a template image** (`isTemplate = true`) so it auto-inverts for light/dark menu bars. Don't hardcode colors on it.
- **Bundle ID** is `io.github.doniyorniazov.UsageDash`. The prefs plist lives at `~/Library/Preferences/<bundle-id>.plist` — changing the bundle ID orphans every existing user's settings.
- **No tests exist.** If you add one, you'll also need to add a test target to `Package.swift`; don't claim "tests pass" without one.
