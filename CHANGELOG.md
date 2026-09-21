# Changelog

All notable changes to DayPeek are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and DayPeek adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Bump the version in this file and in `VERSION` together, in the same pull
request, when you intend to ship. Merging that PR to `master` cuts the release.

## [0.3.0] - 2026-09-21

### Added
- A round pencil button next to **Today** in the panel header toggles the
  hover row actions on and off, sharing the **Show row actions on hover**
  preference. Blue while on, slashed and grey while off.

## [0.2.0] - 2026-09-20

### Added
- Hover actions on open reminders: three round buttons at the row's trailing
  edge to edit the title in place (Return saves, Esc cancels), change the due
  date & time in a popover (month grid, Today / Tomorrow / Next week chips,
  time field, All-day switch), and delete the reminder after a confirmation
  (⌥-click the trash to skip it). Completed rows show no buttons.
- Rescheduling a reminder that has alarms moves its alarm to the new time.
- Preferences: **Show row actions on hover** (on by default) hides the buttons
  for a checklist-only panel.

### Changed
- Only the round checkbox toggles completion now; clicking elsewhere on a row
  does nothing, so a stray click can't tick a reminder off.
- Esc cancels an in-progress title edit before it closes the panel.

## [0.1.0] - 2026-09-14

### Added
- Initial release: a menu-bar-only floating checklist of today's Apple
  Reminders for macOS 14+.
- Menu bar icon: a checklist glyph. The remaining count is shown in
  the panel header and refreshes at midnight and whenever Reminders changes.
- Left-click toggles a floating panel anchored below the icon; right-click (or
  ctrl-click) shows a two-item menu: Preferences… and Quit.
- The panel floats above every app — including fullscreen ones — without
  stealing focus, with a springy pop-down/retract-up open/close animation.
- **Overdue** (red) and **Today** sections sorted by due time, each row with a
  round checkbox in its list colour, the title, due time, and list name.
- Single click marks a reminder complete (saved to Reminders immediately) and
  moves it to a **Completed** section at the bottom, collapsed by default; click
  a completed row to reopen it.
- Resizable panel (280×240 – 560×900); the last size is remembered.
- Esc or click-outside closes the panel (Pin panel keeps it open); the list
  resets to the top for the next open.
- Preferences window: Appearance (System/Light/Dark), pin panel, launch at
  login (`SMAppService`).
- Requires exactly one permission — Reminders — and makes no network requests.
