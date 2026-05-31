## Context

Nudgebar is a native macOS Swift package using SwiftUI for menu-bar/settings/alert views and AppKit where SwiftUI is insufficient (full-screen window, status-item title). The existing `MenuBarView` is wired through SwiftUI's `MenuBarExtra` and surfaces toggles only. `AlertPresenter` builds borderless `NSWindow`s with a hard-coded layout and a Dismiss-only action. Event data comes through a provider-agnostic `CalendarProviderClient` contract (EventKit today); this change must not couple to EventKit-specific types.

The visual design is locked and lives as HTML mockups under `design/` (`alert.html`, `popover.html`, `settings.html`, `icons.html`, `brand-book.html`, `urgent-states.html`). Those, plus the Nudgebar brand tokens (ink/ember/blush/sand/stone, Geist, the Bold States Ring logo), are the source of truth for layout, spacing, and colour. This spec captures behaviour; the mockups capture pixels.

State the new code must own:

- The current upcoming-events list (now -> end of tomorrow, capped at 25), each carrying enriched fields (organizer, calendar colour, duration, location, meeting URL, conference type).
- A per-event "snoozed-until" map.
- A single alert-window controller with an ordered set of due "alert cards".
- A sound-playback handle tied to the alert window's lifecycle.
- Per-calendar rule resolution and the delivery decision (full-screen vs notification).

The countdown text in the menu bar updates at a cadence precise enough to feel live but cheap enough to be invisible (1s within 60 minutes, 60s otherwise).

## Goals / Non-Goals

**Goals:**

- Replace `MenuBarExtra` with a custom `NSStatusItem` so the title can be a live, formatted string and the popover is a real `NSPopover` anchored to the item.
- Centralize alert-window state in a single `AlertWindowController` that owns the one-window-with-many-cards invariant and the warm backdrop.
- Surface enriched, actionable meeting context (Join, conference chip, organizer, calendar colour) wherever an event is shown.
- Make snooze, auto-dismiss, per-calendar rule resolution, and delivery selection deterministic and unit-testable by isolating them from view code.
- Keep `AlertPolicy` provider-agnostic so future providers plug in without alert changes.

**Non-Goals:**

- Per-event alert overrides (per-_calendar_ rules are in scope; per-event is deferred), custom audio-file uploads, queueing/stacking semantics, or new calendar providers.
- Localization beyond the English strings already in the codebase.
- The Reminders data source.

## Decisions

### Replace `MenuBarExtra` with a custom `NSStatusItem`

`MenuBarExtra` cannot expose its title as a live-bound `Text` without flicker, and its popover anchor is opaque. A `StatusItemController` owns an `NSStatusItem`, sets `button.title` from an observable model on every change, and uses a single `NSPopover` whose content view is the SwiftUI `UpcomingPopoverView`.

### Status-item rendering is monochrome and accurate to the platform

A status item can render an image plus a title; it **cannot** render a custom coloured pill or a coloured background behind the text. So:

- The proximity indicator is a **template `NSImage`** (a ring glyph) drawn so that _fill level_ encodes proximity - more of the ring is filled as the event nears (`◔ → ◑ → ◕ → ●`). Because it is a template image the system tints it for light/dark and menu-bar selection; we do not attempt red/amber colour in the menu bar.
- The title text uses the **system label colour**. No pill, no custom background.
- A `StatusItemTitleFormatter` pure function produces the string from `(nextEvent, now)` and is the only place the format lives - fully unit-testable.

Title format: `<ring-glyph> <middle-truncated-title> · <countdown>`, where the countdown is `Nm` within 60 min, `1m` granularity beyond, `now` at zero, and `starts in <30s` under 30 seconds. Title truncated middle-style to `maxTitleChars` (default 24). Past-due events shift to the next upcoming.

### Countdown ticker

`AppModel` owns a `Timer` firing every 1s when the next event is `<= 60` min away, every 60s otherwise. It recomputes the title and (when the popover is open) visible relative times. Calendar polling stays at the existing `pollSeconds` interval.

### Hybrid popover (hero pair + compressed timeline)

`UpcomingPopoverView` renders the locked hybrid layout:

- **Hero pair:** the next one or two events as rich cards - calendar-colour dot, title, time, an "In N min" lead pill, and a **Join** button when a meeting URL is present.
- **Compressed timeline:** the remaining events as dense single-line rows grouped under `Today` / `Tomorrow`, sorted ascending, capped at 25 with a truncation indicator.
- Snoozed events stay in the list with a snooze indicator.
- Empty state: `All clear · no upcoming events`, with quick controls and the Settings link still present.

### Merged alert window with enriched cards (single `AlertWindowController`)

A single `AlertWindowController` owns at most one `NSWindow`. Its content is `AlertOverlayView(cards: [AlertCard])` over a **warm, copper-toned translucent backdrop** (an `NSVisualEffectView`/material tinted toward the brand ember, tuned so the desktop reads faintly while card text stays at AA contrast). When a new event becomes due: create the window with the card if none exists, else append the card to the observable `cards` array (the list animates it in).

Each card shows the enriched fields and owns its own dismiss/snooze actions and per-card auto-dismiss countdown. The window closes only when `cards.isEmpty`. A footer offers **Snooze All** (snooze every card with the default preset) and **Dismiss All**. The sound player is bound to the window lifecycle (one loop while any card is present), so adding a second card does not restart the loop. When an event is at/under the urgent threshold the card and ring take the locked urgent emphasis (`urgent-states.html`).

### Meeting Join and conference detection

A small `ConferenceLink` resolver inspects an event's meeting URL / location / notes for known providers (Zoom, Google Meet, Microsoft Teams, generic) and yields a conference _type_ (for the chip) and a launch URL (for the **Join** button). Detection is pure and unit-tested; the provider contract supplies the raw URL/location so the resolver stays provider-agnostic. If no link is found, no chip or Join button is shown.

### Per-calendar alert rules

A `CalendarAlertRule` per calendar can: enable/disable alerts, override lead time, and override sound. Effective settings resolve as `per-calendar value ?? global default`. Resolution is a pure function `(event, rules, globals) -> EffectiveAlertSettings`, unit-tested. Rules persist in `UserDefaults` keyed by calendar identifier.

### Notification fallback and Focus/DND

The delivery decision is a pure function `(event, preferences, focusState) -> .fullScreen | .notification | .suppressed`:

- If full-screen alerts are disabled for the event's calendar, deliver via `UNUserNotificationCenter`.
- If "respect Focus" is on and the system reports a Focus / Do-Not-Disturb state, fall back to a notification (or suppress, per preference). macOS exposes no fully public Focus API; we detect via the notification-center authorization/active state and treat it conservatively, with a user toggle as the reliable control.
- Otherwise deliver the full-screen window.

### Snooze, auto-dismiss, sound, preferences

(Unchanged from the prior design and already partly implemented.) `SnoozeStore` keeps `[eventID: snoozedUntil]`; effective fire time is `min(snoozedUntil ?? .now, start - effectiveLeadTime)`; in-memory only in MVP. Auto-dismiss is a per-card `Task` with a visible `CountdownRing`; `Never` (sentinel `0`) skips it. `SoundPlayer` wraps `NSSound`, plays on appear and loops every 5s, stops on window close; `AlertSoundCatalog` is the stable picker list. `AlertPreferences` holds `soundName`, `autoDismissSeconds`, per-calendar rules, notification/Focus toggles, shortcut bindings, and shared constants (`snoozePresetMinutes = [1,5,10]`, `autoDismissRangeSeconds = 5...300`, `autoDismissNeverSentinel = 0`, `maxTitleChars`).

### Global keyboard shortcuts

A `GlobalShortcuts` registrar binds user-configurable shortcuts for Snooze All, Dismiss All, and Open popover, using an `NSEvent` global monitor (no third-party hotkey dependency). Bindings persist in preferences and are editable in the Shortcuts settings section.

## Risks / Trade-offs

- **NSStatusItem title flicker on rapid updates** -> throttle title updates to tick boundaries; rebuild the ring `NSImage` only when the fill bucket changes.
- **Borderless `screenSaver`-level window stealing focus during full-screen meetings** -> keep `collectionBehavior` including `.fullScreenAuxiliary` and `.canJoinAllSpaces`; the alert is intentionally intrusive (that is its purpose).
- **Warm translucent backdrop hurting contrast** -> tune material opacity so `data-checkpoint` card text stays >= 4.5:1; verify against light and dark desktops.
- **No public Focus API** -> rely on the user "respect Focus" toggle as the reliable control and best-effort detection otherwise; document the limitation.
- **Global shortcut conflicts** -> validate bindings on entry and surface conflicts in Settings; never register a binding that the OS rejects.
- **Snooze in-memory only** -> documented MVP non-goal; relaunch re-fires at the next computed time.
- **`AppModel` becoming a god object** -> extract `StatusItemController`, `AlertWindowController`, `SnoozeStore`, `SoundPlayer`, `StatusItemTitleFormatter`, `ConferenceLink`, rule resolution, and delivery selection as narrow types; `AppModel` only wires them.

## Migration Plan

First user-facing redesign past the scaffold; no live users to migrate.

1. New `UserDefaults` keys (`soundName`, `autoDismissSeconds`, per-calendar rules, notification/Focus toggles, shortcut bindings) read with default fallbacks, so existing installs adopt new defaults without explicit migration.
2. Existing `fullScreenAlerts` and `leadMinutes` keys remain unchanged and become the global fallback for per-calendar rules.

## Open Questions

- Should `Snooze All` use the global default preset or remember the last per-card choice? Default to the global preset for MVP.
- Should notification-fallback reminders carry a Join action? Desirable; gated on `UNNotificationAction` wiring - include if cheap, else fast-follow.
- Localization of the explicit `Nm` countdown vs `RelativeDateTimeFormatter` - deferred.
