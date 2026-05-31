## ADDED Requirements

### Requirement: Durable settings state
The system SHALL persist user-facing non-secret settings across app restarts.

#### Scenario: Alert setting survives restart
- **WHEN** the user changes alert lead time or full-screen alert mode and restarts the app
- **THEN** the app loads the previously selected setting

### Requirement: Durable account and source metadata
The system SHALL persist connected account metadata and selected source metadata needed to restore provider configuration without storing secrets outside Keychain.

#### Scenario: Connected provider survives restart
- **WHEN** the user connects a provider and restarts the app
- **THEN** the app can display the provider account and selected calendars/sources without requiring reconfiguration

### Requirement: Durable sync cursor state
The system SHALL persist sync cursors and equivalent non-secret metadata needed for provider refresh.

#### Scenario: Incremental sync resumes after restart
- **WHEN** the app restarts after a successful provider sync
- **THEN** the next sync uses the persisted cursor or equivalent metadata instead of always doing a full refresh

### Requirement: Durable alert interaction state
The system SHALL persist alert presentation, dismiss, snooze, and expiry state across app restarts.

#### Scenario: Dismissed alert does not reappear
- **WHEN** the user dismisses an alert and restarts the app before the event ends
- **THEN** the same occurrence is not presented again unless the event materially changes

#### Scenario: Snoozed alert is restored
- **WHEN** the user snoozes an alert and restarts the app before the snooze time
- **THEN** the app preserves the snooze and re-arms the alert for the snooze time

### Requirement: Disposable minimized event cache
The system SHALL treat cached event data as disposable provider-derived state and SHALL store only fields needed for alerting.

#### Scenario: Event cache is rebuilt
- **WHEN** the app launches with no event cache or an invalidated cache
- **THEN** it rebuilds the cache from connected providers using stored account metadata and sync behavior

#### Scenario: Event payload is minimized
- **WHEN** an event is cached
- **THEN** the cache excludes raw provider payloads, private notes, unnecessary attendee details, and other fields not needed for alerting

### Requirement: Replaceable persistence backend
The system SHALL define persistence behind abstractions so the MVP can use a simple durable backend while allowing SQLite or another stronger backend later.

#### Scenario: Backend changes
- **WHEN** the persistence backend is replaced
- **THEN** provider sync, alert planning, and UI-facing settings code continue to use stable persistence interfaces
