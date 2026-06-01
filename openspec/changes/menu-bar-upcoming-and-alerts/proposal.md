## Why

Nudgebar's MVP scaffold installs a menu-bar item, but the status item does not surface the next event, the dropdown does not list upcoming events, and the full-screen alert ships with only a Dismiss button (no snooze, no auto-dismiss, no sound, no meeting context). The product promise is "high-visibility, context-rich calendar reminders" - today the user has to open a separate calendar to know what is coming next and how to join, and a fired alert can sit on screen indefinitely with no audio cue. This change defines the menu-bar surface, the full-screen alert UX, and the supporting preferences so the app delivers on its core value: glanceable next-event awareness and unmissable, actionable alerts.

## What Changes

**Status item & popover**

- The status item shows a monochrome proximity glyph plus the next event's title and a live relative countdown (e.g. `◔ Stand-up · 12m`), middle-truncated to a max width; icon-only when nothing is upcoming. The glyph is a **template image**: proximity is encoded by how full the ring is, not by colour, and the menu bar tints it for light/dark and selection. The title uses the system label colour - there is no custom pill or coloured background (a status item cannot render one).
- Clicking the status item (or a global shortcut) opens a native popover in the locked **hybrid layout**: a hero pair (the next one or two events, each with a calendar-colour dot, time, an "In N min" lead pill, and a Join button when the event has a meeting link) above a compressed timeline of the remaining events from now through end of tomorrow, capped at 25 and grouped `Today` / `Tomorrow`. Empty state reads `All clear · no upcoming events`.

**Full-screen alert**

- A single merged alert window: one window at a time; concurrently-due events (those inside the lead window) are added as additional cards in the same window rather than stacking windows.
- Each card surfaces **enriched context** sourced from the calendar provider: title, start time and duration, calendar name with its colour, organizer, location, an "In N min" lead pill, a conference-type chip (Zoom / Meet / Teams / generic), and a **Join** button when a meeting URL is present.
- Per-card Dismiss and Snooze (presets [1, 5, 10] min); footer **Snooze All** and **Dismiss All** act on every card at once.
- A warm, copper-toned **translucent backdrop** so the desktop reads faintly behind the alert while cards stay high-contrast, with an urgent emphasis when an event is at or under the urgent threshold.
- Configurable auto-dismiss (5-300s or Never, default 30s) with a visible countdown, and a configurable looping system sound.

**Preferences, rules & delivery**

- Settings reorganised into **General, Connectors, Alerts, and Shortcuts** sections.
- **Per-calendar alert rules**: enable/disable alerts and override lead time and sound per calendar, falling back to the global defaults.
- **Global keyboard shortcuts** for Snooze All, Dismiss All, and Open popover.
- **Notification fallback**: when full-screen alerts are disabled, or the system is in a Focus / Do-Not-Disturb state, deliver the reminder as a native notification instead of the full-screen window, per preference.

## Capabilities

### New Capabilities

- `menu-bar-surface`: monochrome status-item title and proximity glyph, the hybrid upcoming-events popover (hero pair + compressed timeline), enriched hero content with Join, empty state, and click/shortcut expand behaviour.
- `full-screen-alerts`: alert window lifecycle, merged enriched event-card layout, warm translucent backdrop, per-card and bulk (Snooze All / Dismiss All) actions, snooze state machine, looping sound, configurable auto-dismiss with visible countdown, the meeting Join affordance, and the notification / Focus delivery fallback.
- `alert-rules-and-shortcuts`: the Settings window structure, per-calendar alert rules, and global keyboard shortcuts.

### Modified Capabilities

None. Nudgebar does not yet have committed OpenSpec specs - all surfaces are introduced here for the first time.

## Impact

- Code in `Sources/Nudgebar/`:
  - `NudgebarApp.swift`: replace `MenuBarExtra` with a custom `NSStatusItem` controller (live title + real `NSPopover`).
  - `MenuBarView.swift` / new `UpcomingPopoverView`: the hybrid hero-pair + timeline popover.
  - `AppModel.swift`: ordered upcoming-events stream, countdown ticker, alert-window lifecycle, snooze map.
  - `AlertPresenter.swift` / new `AlertWindowController`: single merged window, enriched stacked cards, warm backdrop, countdown ring, snooze menu, Snooze-All / Dismiss-All footer.
  - `CalendarProvider.swift` / `AlertCandidate.swift`: the provider contract surfaces organizer, calendar colour, duration, location, and meeting URL / conference type (confirmed available from the connectors).
  - New: a conference-link parser + Join action, per-calendar rules model, notification-fallback delivery, and global-shortcut registration.
  - `AlertPreferences.swift`: `soundName`, `autoDismissSeconds`, per-calendar rule storage, notification-fallback and respect-Focus toggles, shortcut bindings, plus shared constants.
  - `SettingsView.swift`: General / Connectors / Alerts / Shortcuts sections, per-calendar rules, sound + auto-dismiss controls, notification/Focus toggles.
- Tests in `Tests/NudgebarTests/`: snooze re-fire timing, upcoming-list windowing/grouping/cap, merge-vs-new-window behaviour, conference-link parsing, per-calendar rule resolution, and delivery-fallback selection. UI views stay manual-test territory; logic is covered by deterministic unit tests.
- Dependencies: no new third-party deps. Uses AppKit / SwiftUI / EventKit, plus `UNUserNotificationCenter` for the notification fallback and an `NSEvent` global monitor (or Carbon hotkey) for shortcuts.
- Info.plist: add the notification usage entitlement/string if `UNUserNotificationCenter` requires it; existing EventKit strings unchanged.
- Canonical visual source of truth: the locked mockups in `design/` (`alert.html`, `popover.html`, `settings.html`, `icons.html`, `brand-book.html`, `urgent-states.html`) and the Nudgebar brand tokens.
- Out of scope (deferred): per-event (as opposed to per-calendar) overrides, custom audio-file uploads, additional calendar providers beyond the existing contract, the Reminders surface, and any cross-platform UI work.
