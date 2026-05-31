## 1. Preferences and shared constants

- [x] 1.1 Add `soundName` (default `"Glass"`) and `autoDismissSeconds` (default `30`, `0` = Never sentinel) to `AlertPreferences` with `UserDefaults`-backed persistence
- [x] 1.2 Add static constants `snoozePresetMinutes = [1, 5, 10]`, `autoDismissRangeSeconds = 5...300`, `autoDismissNeverSentinel = 0`, and `maxTitleChars` on `AlertPreferences`
- [x] 1.3 Add `AlertSoundCatalog` (static list of `Glass`, `Ping`, `Submarine`, `Funk`, `Blow`, `Hero`, `Pop`, `Tink`) with display labels
- [ ] 1.4 Add per-calendar rule storage (keyed by calendar id), notification-fallback + respect-Focus toggles, and shortcut-binding storage to `AlertPreferences`

## 2. Enriched event model and conference detection

- [ ] 2.1 Extend `AlertCandidate` and the `CalendarProvider` contract to surface organizer, calendar colour, duration, location, and meeting URL (confirmed available from the connectors)
- [ ] 2.2 Map those fields in the EventKit provider implementation
- [ ] 2.3 Add a pure `ConferenceLink` resolver that classifies a meeting URL/location into a conference type (Zoom / Meet / Teams / generic) and a launch URL

## 3. Status item controller and title formatter

- [ ] 3.1 Replace the `MenuBarExtra` scene in `NudgebarApp` with a `StatusItemController` owning an `NSStatusItem` and an `NSPopover`
- [x] 3.2 Implement `StatusItemTitleFormatter.title(for: nextEvent?, now:)` (icon-only, `<title> · 12m`, `<title> · starts in <30s`, etc.)
- [x] 3.3 Render the proximity glyph as a monochrome template ring whose fill encodes proximity (no colour, no pill); title uses the system label colour
- [ ] 3.4 Bind `StatusItemController` to `AppModel.nextUpcomingEvent` and the countdown ticker (1s within 60 min, 60s otherwise)

## 4. Upcoming-events stream and ticker

- [ ] 4.1 Add `AppModel.upcomingEvents: [AlertCandidate]` filtered to `now <= start <= endOfTomorrow`, sorted ascending, capped at 25
- [ ] 4.2 Recompute the upcoming list on calendar poll completion, on snooze, and on dismiss
- [ ] 4.3 Add a `CountdownTicker` firing every 1s when within 60 min of the next event, 60s otherwise

## 5. Hybrid upcoming-events popover

- [ ] 5.1 Build the hero pair in `UpcomingPopoverView`: the next one or two events with calendar-colour dot, time, `In N min` lead pill, and a Join button when a meeting link is present
- [ ] 5.2 Build the compressed timeline of remaining events grouped `Today` / `Tomorrow`, sorted ascending, capped at 25 with a truncation indicator
- [ ] 5.3 Show the empty state `All clear · no upcoming events`
- [ ] 5.4 Surface a snooze indicator on snoozed events
- [ ] 5.5 Add quick controls (full-screen alerts toggle, lead time) plus a Settings link/button
- [ ] 5.6 Mount the view in the `NSPopover`; toggle on status-item click and the Open-popover shortcut; close on Escape, second click, or outside-click

## 6. Snooze state machine

- [x] 6.1 Add `SnoozeStore` (in-memory) keyed by event ID with `snoozedUntil: Date`
- [x] 6.2 Compute effective fire time as `min(snoozedUntil, start - effectiveLeadTime)`
- [x] 6.3 Keep snoozed events in the upcoming list with an indicator; re-fire when the snooze expires
- [x] 6.4 Collapse snooze when the event's start is sooner than the snooze interval

## 7. Merged alert window with enriched cards

- [ ] 7.1 Introduce `AlertWindowController` owning at most one `NSWindow` and an observable `cards: [AlertCard]`
- [ ] 7.2 Implement `present(event:)` that creates the window if absent or appends a card if present, with no window-stacking
- [ ] 7.3 Build the enriched `AlertCard` view: title, start time + duration, calendar-colour dot + name, organizer, location, `In N min` lead pill, conference chip, and Join button - omitting fields that are absent
- [ ] 7.4 Apply the warm copper-toned translucent backdrop (tuned `NSVisualEffectView`/material keeping card text at AA contrast) and the urgent emphasis at/under the urgent threshold
- [ ] 7.5 Implement per-card Dismiss removing only that card and closing the window when `cards.isEmpty`
- [ ] 7.6 Implement per-card Snooze with a `[1, 5, 10]` minute menu that calls `SnoozeStore` and removes the card
- [ ] 7.7 Implement the footer `Snooze All` (default preset) and `Dismiss All` actions
- [ ] 7.8 Keep `collectionBehavior` `.canJoinAllSpaces, .fullScreenAuxiliary, .stationary` and level `.screenSaver`

## 8. Auto-dismiss countdown

- [ ] 8.1 Start a per-card auto-dismiss `Task` on appear using `AlertPreferences.autoDismissSeconds`
- [ ] 8.2 Render a `CountdownRing` (or text countdown) on each card reflecting remaining time
- [ ] 8.3 Skip the task and hide the countdown when the preference equals the `Never` sentinel
- [ ] 8.4 Cancel the task on user Dismiss or Snooze of the same card

## 9. Sound player

- [x] 9.1 Add `SoundPlayer` wrapping `NSSound(named:)` with `start(name:)` (play once + repeat every 5s) and `stop()`
- [ ] 9.2 Own the `SoundPlayer` in `AlertWindowController`; start when the window opens, stop when it closes
- [ ] 9.3 Do not restart the loop when a card is added to an already-visible window
- [x] 9.4 Log and proceed silently when `NSSound(named:)` returns nil

## 10. Notification fallback and Focus

- [ ] 10.1 Implement a pure delivery decision `(event, preferences, focusState) -> .fullScreen | .notification | .suppressed`
- [ ] 10.2 Add the `UNUserNotificationCenter` delivery path (request authorization; notification with title/time, and a Join action when cheap)
- [ ] 10.3 Add best-effort Focus / Do-Not-Disturb detection honouring the respect-Focus toggle
- [ ] 10.4 Route alerts through the delivery decision at fire time

## 11. Per-calendar rules

- [ ] 11.1 Add a `CalendarAlertRule` model (enabled, optional lead-time override, optional sound override) persisted by calendar id
- [ ] 11.2 Implement pure resolution `(event, rules, globals) -> EffectiveAlertSettings`
- [ ] 11.3 Apply the effective lead time, sound, and enabled flag in the alert pipeline

## 12. Global shortcuts

- [ ] 12.1 Add a `GlobalShortcuts` registrar (NSEvent global monitor) for Snooze All, Dismiss All, and Open popover
- [ ] 12.2 Persist bindings and validate/reject conflicting bindings with feedback

## 13. Settings sections

- [ ] 13.1 Reorganise `SettingsView` into `General`, `Connectors`, `Alerts`, and `Shortcuts` sections
- [ ] 13.2 Add the sound picker + Preview and the auto-dismiss control (range + `Never`)
- [ ] 13.3 Add the per-calendar rules UI (enable, lead-time override, sound override)
- [ ] 13.4 Add the notification-fallback and respect-Focus toggles
- [ ] 13.5 Add the shortcuts editor for the three actions
- [ ] 13.6 Keep existing controls (lead time, calendar selection, full-screen alerts toggle) intact

## 14. Tests

- [ ] 14.1 `StatusItemTitleFormatter` covering empty / `<30s` / `Nm` / truncation / glyph-fill bucket
- [ ] 14.2 Upcoming-events filter: window boundaries, ordering, cap, grouping helpers
- [ ] 14.3 Snooze re-fire timing including the snooze-past-start collapse
- [ ] 14.4 Auto-dismiss countdown including the `Never` sentinel and cancellation by user action
- [ ] 14.5 `AlertWindowController` card-merge behaviour (single window, append, dismiss-one, dismiss-all, snooze-all)
- [ ] 14.6 `SoundPlayer` start/stop and no-restart-on-add using a fake clock and injected NSSound stub
- [ ] 14.7 `ConferenceLink` resolver (Zoom / Meet / Teams / generic / none)
- [ ] 14.8 Per-calendar rule resolution (override vs fallback to global)
- [ ] 14.9 Delivery decision (full-screen vs notification vs suppressed under Focus)

## 15. Manual verification

- [ ] 15.1 Status item title format, 1s cadence, and monochrome glyph in light and dark menu bars
- [ ] 15.2 Popover hybrid layout: hero pair, Join, compressed timeline, cap, empty state, quick controls
- [ ] 15.3 Fire a test alert: enriched card content, warm backdrop contrast, sound loops every 5s and stops on dismiss
- [ ] 15.4 Trigger a second event during an active alert and confirm a new card appears in the same window
- [ ] 15.5 `Snooze All` and `Dismiss All` via footer buttons and via shortcuts
- [ ] 15.6 Auto-dismiss countdown is visible and cancels on user action; `Never` leaves the card on screen
- [ ] 15.7 A per-calendar rule (disable a calendar, override its lead time) takes effect
- [ ] 15.8 Notification fallback fires when full-screen alerts are off or the system is in Focus
