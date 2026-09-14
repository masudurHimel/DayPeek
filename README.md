# DayPeek

A minimal, beautiful, floating checklist of **today's Apple Reminders** for the macOS menu bar. Free and open source (MIT), macOS 14+. Sibling of [MonthPeek](https://github.com/masudurHimel/monthpeek).

Click the checklist in your menu bar and a clean card pops down — above whatever you're working on, even fullscreen apps — showing every open reminder due today or overdue. **One click ticks a reminder off** and it's completed in Reminders. Click anywhere else and the card tucks itself back into the bar.

## Features

- **Menu bar only** — no Dock icon, no main window. The icon is a checklist glyph; the count of open reminders lives in the panel header.
- **Left-click** toggles the floating panel; **right-click** (or ctrl-click) gives exactly two menu items: *Preferences…* and *Quit*.
- **Floats above everything** — regular apps, other Spaces, and fullscreen apps — and never steals focus from the app you're using.
- **Overdue** (red) on top, then **Today**, both sorted by due time. Each row shows a round checkbox in its list colour, the title, the due time (or "All-day"), and the list name.
- **Single click completes** a reminder — saved to Reminders instantly — and moves it to a **Completed** section at the bottom, collapsed by default (click the header to expand). Click a completed row to reopen it. The section also lists everything you completed earlier today, in any app.
- **Resizable** by dragging edges/corners (280×240 up to 560×900); the size is remembered.
- **Esc closes**, click-outside closes (unless pinned), springy pop-down/retract-up animation.
- **Preferences**: Appearance (System / Light / Dark), pin panel, launch at login.

## Privacy: one permission, no connection required

- **One permission: Reminders.** DayPeek reads your reminders and writes exactly one field — completed or not — when you click a row. Nothing else is touched. No Calendar events, no Accessibility, no Screen Recording.
- **No network. No connection required.** Zero network requests — no analytics, no telemetry, no update checks.
- **No third-party dependencies.** Pure Swift + SwiftUI + AppKit + EventKit. Small enough to audit in an afternoon.
- The only things it stores are your preferences and panel size, in its own `UserDefaults` domain.

## Install

1. Download `DayPeek-x.y.z.zip` from the [latest release](https://github.com/masudurHimel/DayPeek/releases/latest) and unzip it.
2. Move `DayPeek.app` to `/Applications`.
3. Open `DayPeek.app`, allow Reminders access when asked — the checklist icon appears in your menu bar.

> [!IMPORTANT]
> **You will likely see a warning on first launch** — macOS may say it *"could not verify DayPeek is free of malware"*. **This is expected and the app is completely safe.** DayPeek is open source and built by GitHub Actions straight from this repository, but it is **not notarized by Apple, because the maintainer doesn't have a paid Apple Developer account**. The dialog only offers **Done** and **Move to Bin**, so:
>
> 1. Click **Done** (not Move to Bin).
> 2. Open **System Settings → Privacy & Security**, scroll down to *"DayPeek" was blocked to protect your Mac*, and click **Open Anyway**.
> 3. Confirm, and DayPeek launches. This is needed only once.
>
> Alternatively, run `xattr -d com.apple.quarantine /Applications/DayPeek.app` in Terminal and open the app normally.

## Usage

| Action | Result |
| --- | --- |
| Left-click the menu bar icon | Toggle the reminders panel |
| Right-click / ctrl-click the icon | Menu: Preferences…, Quit |
| Click a reminder row | Mark it complete (moves to Completed) |
| Click a row under Completed | Reopen it |
| Click the Completed header | Expand / collapse today's completed reminders |
| Drag panel edges/corners | Resize (remembered) |
| Drag the panel background | Move the panel |
| Esc or click outside | Close the panel (Pin panel keeps it open); it reopens scrolled to the top |

What counts as "today": open reminders whose due date is before the start of tomorrow (so overdue ones are included), plus anything completed today. Reminders with no due date are not shown.

## Preferences

Right-click the menu bar icon → **Preferences…**

- **Appearance** — System / Light / Dark (the panel follows automatically)
- **Pin panel** — keep the list open when clicking elsewhere
- **Launch at login** — uses Apple's `SMAppService`; no helper app, no daemon

## Build from source

Requires only the **Xcode Command Line Tools** (`xcode-select --install`) — no Xcode, no dependencies.

```bash
git clone https://github.com/masudurHimel/DayPeek.git
cd DayPeek
Scripts/make-app.sh
open build/DayPeek.app
```

`Scripts/make-app.sh` builds a release binary with Swift Package Manager, assembles `build/DayPeek.app`, and ad-hoc signs it. Options:

- `--universal` — build an arm64 + x86_64 binary
- `--install` — copy the result to `/Applications` and launch it (quits any running copy first)

Run the tests with `swift test`. Regenerate the app icon with `Scripts/make-icon.sh`.

> [!NOTE]
> `swift run` alone won't behave correctly — the app must run from a bundle so `LSUIElement` (no Dock icon), the Reminders permission prompt, and `SMAppService` (launch at login) work. Always launch via the built `.app`.

## Releases

Releases are fully automated ([.github/workflows/release.yml](.github/workflows/release.yml)):

1. A PR bumps `VERSION` and adds a matching section to [CHANGELOG.md](CHANGELOG.md).
2. On merge to `master`, CI runs the tests, builds a **universal** app, zips it, tags `vX.Y.Z`, and publishes a GitHub Release with the changelog section as release notes.
3. Nothing happens if the version in `VERSION` is already tagged.

## Project layout

```
Sources/DayPeek/
  DayPeekApp.swift                   Entry point (accessory app, no Dock icon)
  StatusItemController.swift         Menu bar glyph, left/right click routing
  Panel/PeekPanel.swift              Non-activating floating NSPanel
  Panel/PanelController.swift        Show/hide, positioning, reload-on-open, size persistence
  Reminders/DayBuckets.swift         Pure bucketing/sorting (unit tested)
  Reminders/ReminderStore.swift      EventKit: fetch, toggle completion, change observation
  Reminders/RemindersView.swift      SwiftUI card: sections, rows, animations
  Preferences/                       Preferences window + settings storage
Resources/Info.plist                 LSUIElement bundle plist + Reminders usage strings
Scripts/make-app.sh                  Build → bundle → sign
Scripts/make-icon.{sh,swift}         App icon rendered with CoreGraphics
Tests/DayPeekTests/                  DayBuckets tests (swift test)
.github/workflows/                   CI + automated releases
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The short version: keep it minimal, keep it dependency-free, one permission, no network.

## License

[MIT](LICENSE) — free forever.
