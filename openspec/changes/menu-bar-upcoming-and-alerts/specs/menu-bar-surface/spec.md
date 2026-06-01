## ADDED Requirements

### Requirement: Status item shows next upcoming event

The menu bar status item SHALL display a proximity glyph followed by the next upcoming event's title and a live relative countdown when at least one event falls within the upcoming window. When no event is upcoming, the status item SHALL display only the glyph.

The title SHALL be middle-truncated to a fixed maximum character budget so the menu bar layout stays stable, and SHALL use the system label colour (no custom pill or background).

The countdown SHALL update at least once per minute, and at least once per second when the next event is within 60 minutes.

#### Scenario: Event within an hour

- **WHEN** the next upcoming event starts in 12 minutes
- **THEN** the status item displays the proximity glyph, the truncated event title, a separator, and the text `12m`

#### Scenario: Title longer than the budget

- **WHEN** the next event's title is longer than the maximum character budget
- **THEN** the status item displays the title middle-truncated with an ellipsis so the total width does not exceed the budget

#### Scenario: No upcoming events

- **WHEN** the upcoming-events window contains no events
- **THEN** the status item displays only the glyph and no title text

#### Scenario: Event in less than thirty seconds

- **WHEN** the next event starts in 20 seconds
- **THEN** the status item displays a `starts in <30s` countdown indicator and the proximity glyph is rendered in its most-filled (most-urgent) state

### Requirement: Status item proximity glyph is a monochrome template image

The proximity glyph SHALL be rendered as a template image so the menu bar tints it for light/dark appearance and selection; the status item SHALL NOT attempt to colour the glyph or place a coloured background behind the title. Proximity SHALL be encoded by how full the ring glyph is rather than by colour: more of the ring is filled as the event nears.

#### Scenario: Event far out

- **WHEN** the next event starts in 45 minutes
- **THEN** the ring glyph is rendered in a low-fill state as a template image

#### Scenario: Event imminent

- **WHEN** the next event starts in 3 minutes
- **THEN** the ring glyph is rendered in a high-fill state as a template image

#### Scenario: Menu bar appearance change

- **WHEN** the system switches between light and dark menu bar appearance
- **THEN** the glyph follows the menu bar tint without the app recolouring it

### Requirement: Clicking the status item opens the hybrid upcoming-events popover

Clicking the status item (or invoking the Open-popover shortcut) SHALL toggle a native macOS popover anchored under the status item. The popover SHALL present a hybrid layout: a hero pair of the next one or two events shown as rich cards, above a compressed timeline of the remaining events from now through the end of tomorrow, grouped under `Today` and `Tomorrow`, sorted ascending by start time and capped at 25 entries. The popover SHALL contain quick controls for full-screen alerts and lead time and a link to the full Settings window.

#### Scenario: Open the popover

- **WHEN** the user clicks the status item
- **THEN** a popover appears anchored under the status item showing the hero pair above the compressed `Today` / `Tomorrow` timeline

#### Scenario: Hero card shows enriched context

- **WHEN** the next event has a calendar colour and starts in 5 minutes
- **THEN** its hero card shows the calendar-colour dot, the title, the start time, and an `In 5 min` lead pill

#### Scenario: Hero card offers Join for online meetings

- **WHEN** a hero event has a detected meeting link
- **THEN** its hero card shows a Join button that opens the meeting link

#### Scenario: More than the cap

- **WHEN** there are more than 25 upcoming events in the window
- **THEN** the popover shows the first 25 events sorted by start time and indicates that additional events are truncated

#### Scenario: Quick controls available

- **WHEN** the popover is open
- **THEN** it shows a toggle for full-screen alerts, a lead-time control, and a link or button that opens the Settings window

#### Scenario: Close the popover

- **WHEN** the popover is open and the user clicks the status item again, presses Escape, or clicks outside the popover
- **THEN** the popover closes

### Requirement: Empty state messaging

When the upcoming-events window contains no events, the popover SHALL display the message `All clear · no upcoming events` in place of the event list. The quick controls and Settings link SHALL remain available.

#### Scenario: No events in window

- **WHEN** the user opens the popover and no events fall within now through end of tomorrow
- **THEN** the popover displays `All clear · no upcoming events` instead of an event list, and the quick controls and Settings link remain visible

### Requirement: Upcoming events refresh on calendar changes

The upcoming-events list driving both the status item title and the popover SHALL recompute when the underlying calendar data is refreshed, when an alert is dismissed, or when an event is snoozed.

#### Scenario: Calendar refresh

- **WHEN** the calendar provider reports a new or updated event that falls within the upcoming window
- **THEN** both the status item title and the popover list reflect the new ordering within one polling cycle

#### Scenario: Event dismissed from alert

- **WHEN** the user dismisses an alert card for an event
- **THEN** that event is removed from the upcoming-events list for the remainder of this instance

#### Scenario: Event snoozed

- **WHEN** the user snoozes an alert card
- **THEN** the event remains visible in the upcoming-events list with an indicator that it is snoozed, and its next alert fire time reflects the snooze interval
