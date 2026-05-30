# UsageDash

A tiny macOS menu bar app that shows your live Claude usage — current 5-hour session and the 7-day weekly window — right next to the notch.

```
─────────────────────────────────────────
 ✦ 12%                              [Time]
─────────────────────────────────────────
   Claude Usage             14:32:01
   Claude Max 5×

   Current session                4%
   ▰▰░░░░░░░░░░░░░░░░░
   Resets in 2h 14m

   Weekly (7-day)                12%
   ▰▰▰░░░░░░░░░░░░░░░░
   Resets in 5d 3h
─────────────────────────────────────────
```

No dollar amounts, no log scraping, no API key. Reads the same OAuth token Claude Code already stores in your Keychain and surfaces the live rate-limit counters Anthropic returns on every request.

## Install

1. Download `UsageDash-vX.Y.Z.zip` from the [latest release](../../releases/latest).
2. Unzip and drag `UsageDash.app` to `/Applications`.
3. First launch — macOS will block it because the app isn't notarized. Pick one:

   **Easy way** — right-click `UsageDash.app` → **Open** → click **Open** in the dialog. macOS remembers and won't ask again.

   **One-liner** — run this in Terminal once:
   ```
   xattr -dr com.apple.quarantine /Applications/UsageDash.app
   ```

4. The Claude starburst appears in your menu bar.

To launch at login: **System Settings → General → Login Items → Add `UsageDash.app`**.

## Requirements

- macOS 14 (Sonoma) or newer — Apple Silicon or Intel
- An active Claude Pro / Max / Team / Enterprise subscription
- [Claude Code](https://claude.com/claude-code) installed and signed in (so the OAuth token exists in Keychain)

## What you see

**Menu bar** — Claude starburst + the higher of session/weekly utilization, e.g. `✦ 12%`. Renders as a template image so it follows your menu bar's light/dark style.

**Popover** (click the icon)
- Your plan tier (Max 5×, Max 20×, Pro, Team, Enterprise)
- **Current session** — 5-hour window utilization, bar tinted Claude orange, time until reset
- **Weekly (7-day)** — rolling 7-day window utilization and reset countdown
- Refresh / Settings / Quit

**Settings** — probe interval (1 / 5 / 15 / 30 minutes, default 5).

## How it works

There's no public read-only endpoint for live session/weekly counters. The numbers come back as response headers on every `/v1/messages` call:

| Header | Used for |
| --- | --- |
| `anthropic-ratelimit-unified-5h-utilization` | Current session % |
| `anthropic-ratelimit-unified-5h-reset` | Session reset time |
| `anthropic-ratelimit-unified-7d-utilization` | Weekly % |
| `anthropic-ratelimit-unified-7d-reset` | Weekly reset time |

So the app sends a 1-token message to Claude Haiku every N minutes and reads those headers. At the default 5-min interval, ≈ 288 probes/day × ~9 tokens — well under a tenth of a cent per day, and a rounding error against your actual window. Plan info is fetched once at launch from the unrestricted `/api/oauth/profile` endpoint.

## Privacy

UsageDash does exactly this:
- Reads one Keychain item: `Claude Code-credentials` (your OAuth token, same one `claude` itself uses)
- Sends `POST https://api.anthropic.com/v1/messages` with the body `{"model":"claude-haiku-4-5","max_tokens":1,"messages":[{"role":"user","content":"."}]}`
- Sends `GET https://api.anthropic.com/api/oauth/profile` once at launch
- Stores one number locally in `~/Library/Preferences/io.github.doniyorniazov.UsageDash.plist` (your chosen probe interval)

No telemetry, no third-party services, no log files. All code is in `Sources/UsageDash/` — about 350 lines.

## Build from source

Requires Xcode Command Line Tools (`xcode-select --install`) — full Xcode is **not** needed.

```
git clone https://github.com/doniyorniazov/usage-dash.git
cd usage-dash
./build.sh                 # produces UsageDash.app and dist/UsageDash-v0.1.0.zip
open UsageDash.app
```

Pass a version explicitly: `./build.sh 0.2.0` (drives `Info.plist` and the zip filename).

## Project layout

```
Package.swift
build.sh                          # builds .app + zips for release
LICENSE                           # MIT
.github/workflows/release.yml     # builds on git tag push, attaches zip to Release
Sources/UsageDash/
  UsageDashApp.swift              # @main, MenuBarExtra, Settings scene, icon loading
  PopoverView.swift               # popover content
  SettingsView.swift              # probe interval picker
  UsageStore.swift                # observable state + timer
  UsageProbe.swift                # /v1/messages probe + header parser
  ProfileFetcher.swift            # /api/oauth/profile (plan tier)
  Keychain.swift                  # read Claude Code OAuth token
  LimitState.swift                # data struct
  ClaudeMark.swift                # fallback starburst shape if PNG missing
  Formatters.swift                # "42%", "2h 14m"
  Resources/ClaudeIcon.png        # template menu-bar icon
```

## Releasing (maintainer)

```
git tag v0.2.0
git push origin v0.2.0
```

GitHub Actions builds on macOS 14, ad-hoc signs the app, zips it via `ditto`, and attaches the zip to a new GitHub Release. Manual trigger also works via the **Run workflow** button on the Actions tab.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| "App is damaged and can't be opened" | Quarantine flag from download | `xattr -dr com.apple.quarantine /Applications/UsageDash.app` |
| Menu bar shows `0%` and an error in the popover | No Keychain item | Sign in with Claude Code: open Terminal, run `claude`, complete OAuth |
| Menu bar icon missing | Hidden behind the notch | Use Ice / Bartender, or remove a couple other menu bar icons |
| `OAuth token rejected` after weeks | Token expired | Run `claude` once to refresh, then click Refresh in the popover |
| Wrong plan name shown | Anthropic added a new `rate_limit_tier` | Edit `ProfileFetcher.prettyTier` and PR welcome |

## Not affiliated

UsageDash is an unofficial third-party tool. "Claude" is a trademark of Anthropic. The menu-bar icon is a stylized starburst loosely inspired by Claude's mark — not the official logo.

## License

[MIT](./LICENSE) © 2026 Doniyor Niazov
