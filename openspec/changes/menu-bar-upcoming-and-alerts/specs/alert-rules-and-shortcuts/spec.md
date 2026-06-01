## ADDED Requirements

### Requirement: Settings window is organised into sections

The Settings window SHALL organise preferences into `General`, `Connectors`, `Alerts`, and `Shortcuts` sections. Existing controls (calendar selection, lead time, full-screen alerts toggle, sound, auto-dismiss) SHALL remain available within the appropriate section.

#### Scenario: Sections present

- **WHEN** the user opens Settings
- **THEN** they can navigate between `General`, `Connectors`, `Alerts`, and `Shortcuts` sections

#### Scenario: Existing controls preserved

- **WHEN** the user opens the `Alerts` section
- **THEN** the lead-time, full-screen-alerts, sound, and auto-dismiss controls are present and functional

### Requirement: Per-calendar alert rules

The system SHALL allow the user to define alert rules per calendar that can enable or disable alerts for that calendar and override the lead time and the sound. When a rule does not override a value, the global default SHALL apply. Rules SHALL persist across app restarts.

#### Scenario: Disable alerts for a calendar

- **WHEN** the user disables alerts for a specific calendar
- **THEN** events on that calendar do not produce alerts while events on other calendars still do

#### Scenario: Per-calendar lead-time override

- **WHEN** a calendar has a lead-time override of 10 minutes and the global default is 5 minutes
- **THEN** events on that calendar fire their alert 10 minutes before start, while events on calendars without an override use 5 minutes

#### Scenario: Fallback to global default

- **WHEN** a calendar rule overrides the sound but not the lead time
- **THEN** events on that calendar use the overridden sound and the global lead time

#### Scenario: Rules persist

- **WHEN** the user sets per-calendar rules and restarts the app
- **THEN** the rules are still in effect

### Requirement: Global keyboard shortcuts

The system SHALL provide user-configurable global keyboard shortcuts for `Snooze All`, `Dismiss All`, and `Open popover`, editable in the `Shortcuts` section and persisted across restarts. An invalid or conflicting binding SHALL be rejected with feedback rather than silently registered.

#### Scenario: Dismiss all via shortcut

- **WHEN** an alert window is visible and the user presses the configured `Dismiss All` shortcut
- **THEN** every card is dismissed and the window closes

#### Scenario: Snooze all via shortcut

- **WHEN** an alert window is visible and the user presses the configured `Snooze All` shortcut
- **THEN** every card is snoozed by the default preset and the window closes

#### Scenario: Open popover via shortcut

- **WHEN** the user presses the configured `Open popover` shortcut
- **THEN** the upcoming-events popover opens anchored under the status item

#### Scenario: Conflicting binding rejected

- **WHEN** the user attempts to assign a shortcut the system reports as unavailable or conflicting
- **THEN** the binding is rejected with feedback and the previous binding is retained
