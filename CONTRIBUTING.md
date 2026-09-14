# Contributing to DayPeek

Thanks for your interest! DayPeek is deliberately small — the reminders you
need to look at today, one click to tick them off — so the bar for new
features is "does this keep the app minimal?". Bug fixes and polish are always
welcome.

## Ground rules

- **No third-party dependencies.** The project builds with the Xcode Command
  Line Tools alone and must stay that way.
- **One permission, no network.** DayPeek asks for Reminders access and nothing
  else, and never makes a network request. PRs that add another permission or
  any networking will be declined regardless of the feature.
- **macOS 14+** is the deployment target.

## Getting started

```bash
git clone https://github.com/masudurHimel/DayPeek.git
cd DayPeek
Scripts/make-app.sh      # build + bundle + ad-hoc sign
open build/DayPeek.app
```

Run the tests with `swift test`. If you have full Xcode, `xed .` opens the
package as a regular Xcode project.

## Making changes

1. Fork and branch from `master`.
2. Keep the bucketing/sorting logic in `Reminders/DayBuckets.swift` pure and
   covered by tests in `Tests/DayPeekTests/`. EventKit stays confined to
   `Reminders/ReminderStore.swift`.
3. Run `swift test` and click through the app (left-click panel, right-click
   menu, tick/untick a reminder, resize, Esc) before opening a PR.
4. Don't bump `VERSION` in feature PRs — releases are cut separately (see
   below).

## Releasing (maintainers)

A release is cut automatically by GitHub Actions when a commit on `master`
changes `VERSION` to a semver value that has no `vX.Y.Z` tag yet:

1. Add a section for the new version to `CHANGELOG.md`.
2. Set the same version in `VERSION`.
3. Merge to `master`. CI builds a universal binary, zips the app, tags the
   commit, and publishes a GitHub Release with the changelog section as notes.
