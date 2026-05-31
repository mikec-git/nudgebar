## ADDED Requirements

### Requirement: Full-screen alert window appears at configured lead time

When an event's start time minus the effective lead time has been reached, and full-screen alerts are enabled for that event's calendar, the system SHALL display a full-screen alert window for that event. The alert SHALL appear above other windows and be visible across all Spaces.

#### Scenario: Lead time reached

- **WHEN** an event is configured with a 5-minute lead time and 5 minutes remain until its start
- **THEN** a full-screen alert window appears showing that event's card

#### Scenario: Full-screen alerts disabled

- **WHEN** full-screen alerts are disabled for the event's calendar and the lead time is reached
- **THEN** no full-screen alert window appears and the reminder is delivered per the notification fallback

#### Scenario: Alert visible across spaces

- **WHEN** the user is working in a different macOS Space when an alert fires
- **THEN** the alert window appears on the current Space rather than the Space where the app was last active

### Requirement: Enriched alert card content

Each event card SHALL surface the enriched context provided by the calendar provider: the event title, start time and duration, the calendar name with its colour, the organizer when present, the location when present, and an "In N min" lead pill. Fields that are absent for an event SHALL be omitted rather than shown empty.

#### Scenario: Card shows meeting context

- **WHEN** an event with a calendar colour, an organizer, a 30-minute duration, and a location fires an alert
- **THEN** its card shows the title, the start time and duration, the calendar-colour dot and name, the organizer, the location, and an `In N min` lead pill

#### Scenario: Missing fields omitted

- **WHEN** an event has no location and no organizer
- **THEN** its card omits the location and organizer rows rather than rendering empty placeholders

### Requirement: Meeting join affordance and conference chip

When an event has a detectable meeting link, the card SHALL show a conference-type chip identifying the provider (for example Zoom, Google Meet, Microsoft Teams, or a generic label) and a Join button that opens the meeting link. When no meeting link is detected, neither the chip nor the Join button SHALL be shown.

#### Scenario: Online meeting

- **WHEN** an event's details contain a recognised meeting link
- **THEN** the card shows the matching conference-type chip and a Join button that opens that link

#### Scenario: In-person event

- **WHEN** an event has no detectable meeting link
- **THEN** the card shows neither a conference chip nor a Join button

### Requirement: Warm translucent alert backdrop

The alert window SHALL present a warm, copper-toned translucent backdrop through which the desktop is faintly visible, while keeping card text and controls at WCAG AA contrast. When an event is at or under the urgent proximity threshold, the alert SHALL apply the locked urgent emphasis.

#### Scenario: Backdrop is translucent

- **WHEN** the alert window is on screen over a desktop
- **THEN** the desktop reads faintly through a warm-toned translucent backdrop and the card content remains at AA contrast

#### Scenario: Urgent emphasis

- **WHEN** an alert's event is at or under the urgent proximity threshold
- **THEN** the card and proximity indicator render in the urgent emphasis

### Requirement: One alert window with merged event cards

At most one full-screen alert window SHALL be on screen at any given time. When additional events become due while the alert window is already visible, the system SHALL add each new event as an additional card inside the same window rather than opening a new window or stacking windows.

#### Scenario: Single event due

- **WHEN** one event becomes due and no alert window is currently visible
- **THEN** a new alert window opens with a single event card

#### Scenario: Second event becomes due during active alert

- **WHEN** the alert window is visible with one card and a second event becomes due
- **THEN** the second event is appended as a new card inside the same window

#### Scenario: Card dismissed but other cards remain

- **WHEN** the alert window has two cards and the user dismisses one
- **THEN** the dismissed card is removed and the window remains open showing the remaining card

#### Scenario: Last card dismissed

- **WHEN** the alert window has one card and the user dismisses it
- **THEN** the window closes

### Requirement: Per-card dismiss and snooze actions

Each event card SHALL provide a Dismiss button and a Snooze button. The Snooze button SHALL open a menu of fixed presets [1 minute, 5 minutes, 10 minutes]. Selecting a preset SHALL remove the card from the window and re-fire the event at the earlier of (now plus the snooze interval) or (event start minus remaining effective lead time).

#### Scenario: Dismiss a card

- **WHEN** the user clicks Dismiss on an event card
- **THEN** the card is removed from the window and the event is not re-fired this instance

#### Scenario: Snooze for five minutes

- **WHEN** the user clicks Snooze and chooses 5 minutes on an event card at time T
- **THEN** the card is removed and the event re-fires at T + 5 minutes or at the effective pre-event lead time, whichever comes first

#### Scenario: Snooze collapses past event start

- **WHEN** the user snoozes an event for 10 minutes but the event's start time falls within those 10 minutes
- **THEN** the event re-fires at the event's start time rather than at the end of the snooze interval

### Requirement: Bulk snooze-all and dismiss-all footer actions

The alert window SHALL display footer actions labelled `Snooze All` and `Dismiss All` whenever it contains at least one card. `Dismiss All` SHALL dismiss every card. `Snooze All` SHALL snooze every card using the default snooze preset, applying the same re-fire rule as a per-card snooze.

#### Scenario: Dismiss all with multiple cards

- **WHEN** the alert window contains three cards and the user clicks `Dismiss All`
- **THEN** every card is removed and the window closes

#### Scenario: Snooze all with multiple cards

- **WHEN** the alert window contains three cards and the user clicks `Snooze All`
- **THEN** every card is snoozed by the default preset, the window closes, and each event re-fires per the snooze re-fire rule

#### Scenario: Bulk action with one card

- **WHEN** the alert window contains a single card and the user clicks `Dismiss All`
- **THEN** the card is removed and the window closes, with the same result as the card's own Dismiss button

### Requirement: Notification fallback and Focus awareness

When full-screen alerts are disabled for an event's calendar, the system SHALL deliver the reminder as a native notification instead of a full-screen window. When the user has enabled "respect Focus" and the system is in a Focus / Do-Not-Disturb state, the system SHALL fall back to a notification (or suppress the alert, per preference) rather than showing the full-screen window.

#### Scenario: Full-screen disabled for calendar

- **WHEN** an event whose calendar has full-screen alerts disabled reaches its lead time
- **THEN** the reminder is delivered as a native notification and no full-screen window appears

#### Scenario: Focus active with respect-Focus enabled

- **WHEN** "respect Focus" is enabled and the system is in a Focus / Do-Not-Disturb state at an event's lead time
- **THEN** the reminder falls back to a notification (or is suppressed per preference) instead of a full-screen window

### Requirement: Configurable auto-dismiss with countdown

The system SHALL expose a global preference for `Auto-dismiss after` with a range of 5 to 300 seconds or the value `Never`, defaulting to 30 seconds. When auto-dismiss is enabled, each event card SHALL display a visible countdown that decreases over time and SHALL be dismissed automatically when the countdown reaches zero. When set to `Never`, no countdown is shown and cards persist until the user acts.

The auto-dismiss countdown for a card SHALL be cancelled when the user dismisses or snoozes that card.

#### Scenario: Auto-dismiss triggers

- **WHEN** auto-dismiss is set to 30 seconds and an event card has been visible for 30 seconds without interaction
- **THEN** the card is removed automatically and the user sees no further action required for that event this instance

#### Scenario: Countdown visible

- **WHEN** a card appears with auto-dismiss set to 30 seconds
- **THEN** the card displays a visible countdown indicator that reflects the remaining time

#### Scenario: Never

- **WHEN** the user sets auto-dismiss to `Never`
- **THEN** event cards persist indefinitely until the user dismisses or snoozes them, and no countdown indicator is shown on cards

#### Scenario: User action cancels auto-dismiss

- **WHEN** a card has 5 seconds remaining on its auto-dismiss countdown and the user clicks Snooze
- **THEN** the auto-dismiss task for that card is cancelled and only the snooze behavior takes effect

### Requirement: Configurable alert sound that loops while visible

The system SHALL expose a global preference for the alert sound, chosen from a fixed catalog of macOS system sounds (NSSound names). When an alert window appears the chosen sound SHALL play once immediately and then repeat every 5 seconds for as long as the window remains visible. Adding additional cards to an already-visible window SHALL NOT restart or stack the sound loop. The loop SHALL stop immediately when the window closes for any reason (last card dismissed, dismiss-all, snooze-all, all cards auto-dismissed, or all cards snoozed).

#### Scenario: Sound plays on alert appearance

- **WHEN** an event becomes due and the alert window opens
- **THEN** the configured system sound plays once immediately

#### Scenario: Sound loops every five seconds

- **WHEN** the alert window has been visible for 10 seconds
- **THEN** the configured sound has played at 0 seconds and again at 5 seconds, and is scheduled to play again at 10 seconds

#### Scenario: Sound stops on dismiss

- **WHEN** the last card is dismissed or auto-dismissed
- **THEN** the sound stops immediately and the window closes

#### Scenario: Adding a card does not restart the loop

- **WHEN** the alert window is already visible and a second card is added
- **THEN** the existing sound loop continues uninterrupted and is not restarted

### Requirement: Settings expose sound and auto-dismiss controls

The Settings window SHALL provide a sound picker showing the catalog of available system sounds with a Preview button that plays the selected sound once without looping. The Settings window SHALL also provide an auto-dismiss control covering the configured range plus the `Never` option, persisted to user preferences.

#### Scenario: Sound preview

- **WHEN** the user selects a sound from the picker and clicks Preview
- **THEN** the selected sound plays exactly once and does not loop

#### Scenario: Sound persists

- **WHEN** the user selects a new sound and dismisses Settings
- **THEN** the new sound is used for the next alert and persists across app restarts

#### Scenario: Auto-dismiss persists

- **WHEN** the user changes the auto-dismiss value to 60 seconds
- **THEN** the next alert card uses a 60-second countdown and the value persists across app restarts

#### Scenario: Set to never

- **WHEN** the user changes the auto-dismiss control to `Never`
- **THEN** subsequent alert cards display no countdown and persist until the user dismisses or snoozes them
