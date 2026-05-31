# calendar-provider-sync Specification

## Purpose
TBD - created by archiving change non-ui-foundation. Update Purpose after archive.
## Requirements
### Requirement: MVP provider connectors
The system SHALL provide sync-capable provider connectors for EventKit, Google Calendar, Microsoft Graph Calendar, CalDAV, Calendly, Cal.com, and Acuity.

#### Scenario: Provider registry lists MVP providers
- **WHEN** the app enumerates supported providers
- **THEN** the registry includes EventKit, Google Calendar, Microsoft Graph Calendar, CalDAV, Calendly, Cal.com, and Acuity

#### Scenario: Providers expose sync operations
- **WHEN** a provider connector is used by the sync coordinator
- **THEN** it supports account/source discovery, initial sync, incremental or polling sync, cancellation/deletion handling, and normalization into alert occurrences

### Requirement: Canonical alert occurrence normalization
The system SHALL normalize provider-specific events and scheduling bookings into a canonical alert occurrence model consumed by the alert engine.

#### Scenario: Provider event becomes alert occurrence
- **WHEN** a provider returns an upcoming event or booking
- **THEN** the connector emits an alert occurrence with provider identity, source identity, start/end time, timezone metadata, display fields, sync metadata, and alert-relevant status

#### Scenario: Provider-specific payloads stay outside alert planning
- **WHEN** the alert planner evaluates upcoming alerts
- **THEN** it reads canonical alert occurrence fields rather than branching on raw provider payloads

### Requirement: Provider sync state
The system SHALL persist provider-specific sync cursors or equivalent metadata needed for efficient refreshes.

#### Scenario: Google sync token is used
- **WHEN** Google incremental sync succeeds
- **THEN** the next sync token is persisted for the calendar source

#### Scenario: Microsoft delta link is used
- **WHEN** Microsoft delta sync succeeds
- **THEN** the delta link is persisted for the calendar source

#### Scenario: CalDAV sync metadata is used
- **WHEN** CalDAV sync succeeds
- **THEN** collection sync tokens or object ETags are persisted for later refreshes

### Requirement: Local-first sync without webhooks
The system SHALL use polling, provider delta mechanisms, and local change notifications for MVP sync, without requiring a public webhook endpoint.

#### Scenario: Provider webhook is unavailable
- **WHEN** the app is running without backend infrastructure
- **THEN** Google, Microsoft, CalDAV, and scheduling data still refresh through local sync mechanisms

### Requirement: Cross-provider alert dedupe
The system SHALL group duplicate occurrences across providers for alerting while retaining provider-specific source records.

#### Scenario: Direct provider duplicates EventKit event
- **WHEN** the same event is present through EventKit and a direct provider
- **THEN** the alert engine receives one alert group and prefers the direct provider for alert display

#### Scenario: Scheduling booking duplicates calendar event
- **WHEN** a scheduling API booking represents the same meeting as a calendar event
- **THEN** the app suppresses duplicate alert presentation without deleting either source record

### Requirement: Fixture-based provider verification
The system SHALL verify provider behavior with realistic fixtures or local test services and SHALL NOT require live external provider calls in automated tests.

#### Scenario: Provider tests run offline
- **WHEN** automated provider tests run
- **THEN** they complete without calling live Google, Microsoft, CalDAV, Calendly, Cal.com, or Acuity services

