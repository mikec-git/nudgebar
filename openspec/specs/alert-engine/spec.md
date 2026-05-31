# alert-engine Specification

## Purpose
TBD - created by archiving change non-ui-foundation. Update Purpose after archive.
## Requirements
### Requirement: Alert planning from local occurrences
The system SHALL compute upcoming alerts from normalized local occurrences and user alert preferences.

#### Scenario: Event is inside alert window
- **WHEN** an upcoming occurrence starts within the configured lead time
- **THEN** the alert planner marks the occurrence as due for presentation

#### Scenario: All-day or non-alertable event is filtered
- **WHEN** an occurrence is not eligible for alerting according to provider status, event status, or user preferences
- **THEN** the alert planner excludes it from due alerts

### Requirement: One-shot scheduling and reconciliation
The system SHALL schedule the next due alert from local state and reconcile alert plans after lifecycle changes.

#### Scenario: Next alert is scheduled
- **WHEN** the event cache and alert state are updated
- **THEN** the scheduler arms the next due alert rather than continuously polling every few seconds

#### Scenario: Wake reconciliation occurs
- **WHEN** the Mac wakes from sleep
- **THEN** the app reconciles overdue and upcoming alerts before scheduling the next alert

### Requirement: Persistent dismiss and snooze behavior
The system SHALL support dismiss and snooze actions that persist across restarts.

#### Scenario: User dismisses alert
- **WHEN** the user dismisses an alert
- **THEN** the alert state records the dismissal and suppresses repeat presentation for the same occurrence

#### Scenario: User snoozes alert
- **WHEN** the user snoozes an alert
- **THEN** the alert state records the snooze time and the scheduler re-arms the occurrence for that time

### Requirement: Full-screen presentation handoff
The system SHALL expose alert presentation events that a macOS AppKit presentation layer can display as full-screen windows across active displays.

#### Scenario: Alert becomes due
- **WHEN** an alert occurrence becomes due
- **THEN** the alert engine emits a presentation request with sanitized display data and stable alert identity

### Requirement: Local notification backup
The system SHALL provide a local notification backup path for near-term alerts without treating notifications as the primary full-screen alert mechanism.

#### Scenario: Backup notification is scheduled
- **WHEN** upcoming alerts are known
- **THEN** the app can schedule local notifications for a limited upcoming window as a backup

### Requirement: Lifecycle and environment observers
The system SHALL reconcile alert state when relevant macOS lifecycle or environment events occur.

#### Scenario: Display configuration changes
- **WHEN** display configuration changes while an alert is active
- **THEN** the app can rebuild or update alert presentation for the current displays

#### Scenario: Network returns
- **WHEN** network connectivity returns after being unavailable
- **THEN** provider sync can refresh data and the alert scheduler reconciles from updated occurrences

### Requirement: Behavior-focused alert tests
The system SHALL verify alert planning, dedupe, dismiss, snooze, and lifecycle reconciliation through deterministic behavior tests.

#### Scenario: Tests cover user workflows
- **WHEN** alert engine tests run
- **THEN** they assert user-visible alert behavior rather than incidental implementation details such as timer internals or call order

