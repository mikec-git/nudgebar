<p align="center">
  <img src="docs/logo.svg" width="560" alt="Nudgebar">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-1f1f1f?logo=apple&logoColor=white" alt="macOS 13+">
  <img src="https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white" alt="Swift 6.0">
  <a href="https://github.com/mikec-git/nudgebar/actions/workflows/ci.yml"><img src="https://github.com/mikec-git/nudgebar/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-3A8F5B" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/version-0.1.0-FFD6CC" alt="version 0.1.0">
</p>

<p align="center">
  <b>Nudgebar</b> is a native macOS menu-bar app that gives you high-visibility,
  hard-to-miss reminders before your meetings and events.
</p>

---

## Why

Calendar notifications are easy to miss — a banner slides in while you're heads-down
and slides away. Nudgebar lives in the menu bar with a live countdown to your next
event, and when something is about to start it can take over the screen with a clear,
one-glance alert (with a one-tap Join for video calls) so you actually show up.

## Screenshots

<p align="center">
  <img src="docs/screenshots/alert.png" width="660" alt="Full-screen alert"><br>
  <em>Full-screen alert — title, time, countdown ring, snooze, and one-tap Join.</em>
</p>

<p align="center">
  <img src="docs/screenshots/popover.png" width="300" alt="Menu-bar popover"><br>
  <em>Menu-bar popover — upcoming events grouped by Today / Tomorrow, with per-calendar colors.</em>
</p>

## Features

**Menu bar**

- Status item with a live countdown to your next event; left-click for the popover,
  right-click for Open / Settings / Quit.

**Popover**

- A hero pair of the next one or two actionable events with one-tap Join for video links.
- The rest of the day on a compressed **Today / Tomorrow** timeline.
- Per-calendar color dots and source names, `in 5 min` / `in 1h 20m` lead pills, and
  clickable locations and meeting links.
- Refresh button plus quick Full-screen-alerts and Lead-time controls.

**Full-screen alerts**

- A centered, high-visibility card over a warm translucent backdrop.
- Title, time, duration, calendar, organizer, and location; conference chip and Join.
- Snooze presets (limited to the time actually remaining) and Dismiss; Snooze All /
  Dismiss All when several stack up.
- A smooth auto-dismiss countdown ring, **Escape** to dismiss, and a looping alert
  sound until you snooze or dismiss.

**Calendars & sources**

- Reads local macOS calendars via EventKit — which already covers **Google, Outlook /
  Microsoft 365, and iCloud** once they're added to macOS (Internet Accounts), with no
  client IDs or extra logins.
- Enable/disable each calendar individually, with an optional per-calendar lead-time
  override.
- Watches for calendar changes and **re-arms alerts when events are rescheduled**;
  configurable poll interval and a manual refresh.
- Direct connectors (beta): **Calendly** (Personal Access Token) and **Cal.com**
  (API v2) for scheduled bookings, with an in-app setup guide and per-account sync status.

**Alerts & behavior**

- Configurable lead time (global and per calendar).
- Full-screen alert or a notification fallback; best-effort Focus respect.
- Opt-in all-day-event alerts with a chosen time, day offset, and delivery style.
- Auto-dismiss from 5 seconds up to Never.
- A catalog of bundled alert sounds (real ambient recordings + notification tones) with
  preview, and a one-click test alert.

**System**

- Launch at login.
- Global keyboard shortcuts for Snooze All / Dismiss All / Open popover (recordable,
  with conflict detection).
- Keychain-backed credentials; non-secret preferences stored locally.

## Install

### Build from source (works today)

Requires macOS 13+ and a Swift 6 toolchain (Xcode 16 / Command Line Tools).

```sh
git clone https://github.com/mikec-git/nudgebar.git
cd nudgebar
make package
open dist/Nudgebar.app
```

On first launch, grant Calendar access when prompted (or **Settings → Calendars →
Grant Access**). The permission prompt works best from the packaged app, since macOS
reads the usage description from `Info.plist`.

### Homebrew (planned)

Once a tap and a signed release are published, install will be:

```sh
brew install --cask mikec-git/tap/nudgebar
```

A ready-to-publish cask is scaffolded in
[`packaging/homebrew/nudgebar.rb`](packaging/homebrew/nudgebar.rb) (see the header for
the publishing steps). The build is currently ad-hoc signed and not notarized, so until
it is, first launch needs a right-click → **Open** to get past Gatekeeper.

## Development

```sh
make swift-test      # run the test suite (127 tests)
swift build          # debug build
swift run Nudgebar   # run from source (calendar prompts work best from the bundle)
make package         # build dist/Nudgebar.app
```

CI runs `swift build` and `swift test` on macOS for every push and PR
(`.github/workflows/ci.yml`). See [`docs/build-and-test.md`](docs/build-and-test.md)
for local toolchain notes.

## Project layout

| Path                           | What                                                                    |
| ------------------------------ | ----------------------------------------------------------------------- |
| `Sources/Nudgebar`             | The macOS app: menu bar, popover, full-screen alerts, settings, sounds  |
| `Sources/NudgebarCore`         | Provider-agnostic models and sync contracts                             |
| `Sources/NudgebarProviders`    | Calendar / scheduling provider implementations                          |
| `Sources/NudgebarAuth`         | Keychain-backed credential boundary                                     |
| `Sources/NudgebarMacOSSupport` | EventKit + notification integration                                     |
| `design/`                      | Canonical HTML brand book and UI mockups                                |
| `docs/`                        | Architecture notes, provider matrix, build/test docs                    |
| `Resources/Sounds/`            | Bundled alert sounds ([sources & licenses](Resources/Sounds/README.md)) |

## License

[MIT](LICENSE). Bundled alert sounds are third-party works under their own licenses
(public domain / CC0 and the Mixkit Free License) — see
[`Resources/Sounds/README.md`](Resources/Sounds/README.md).
