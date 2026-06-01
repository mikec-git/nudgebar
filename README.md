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
  High-visibility, hard-to-miss menu-bar reminders for macOS - so you actually show up.
</p>

---

### Your day at a glance

<table>
<tr>
<td width="58%" valign="top">

The menu-bar popover leads with your next event or two (one-tap **Join** for video calls), then a compact **Today / Tomorrow** timeline. Per-calendar colors, `in 5 min` pills, and clickable links. The status item counts down to what's next.

</td>
<td width="42%" valign="top"><img src="docs/screenshots/popover.png" width="320" alt="Menu-bar popover"></td>
</tr>
</table>

### Impossible to miss

<table>
<tr>
<td width="52%" valign="top"><img src="docs/screenshots/alert.png" width="440" alt="Full-screen alert"></td>
<td width="48%" valign="top">

When an event is due, a full-screen card takes over: countdown ring, **Snooze** (capped to the time left), **Dismiss**, **Join**, and a looping sound. Press **Esc** to clear, or **Snooze / Dismiss All** when they stack.

</td>
</tr>
</table>

### Tuned your way

<table>
<tr>
<td width="58%" valign="top">

Per-calendar rules, alert sounds, lead time, all-day alerts, auto-dismiss, global shortcuts, and launch at login. Reads **EventKit** (Google / Outlook / iCloud via macOS) plus **Calendly** and **Cal.com** connectors - and re-arms alerts when events move.

</td>
<td width="42%" valign="top"><img src="docs/screenshots/settings.png" width="420" alt="Settings window"></td>
</tr>
</table>

## Install

Build from source (macOS 13+, Swift 6 / Xcode 16):

```sh
git clone https://github.com/mikec-git/nudgebar.git
cd nudgebar && make package && open dist/Nudgebar.app
```

Grant Calendar access on first launch. Homebrew is planned - `brew install --cask mikec-git/tap/nudgebar` ([cask scaffold](packaging/homebrew/nudgebar.rb)); the build isn't notarized yet, so first launch needs a right-click -> **Open**.

## Develop

```sh
make swift-test      # 127 tests
swift run Nudgebar   # run from source
```

CI runs `swift build` + `swift test` on macOS. Sounds are CC0 / public-domain + Mixkit-Free ([licenses](Resources/Sounds/README.md)).

## License

[MIT](LICENSE).
