## ADDED Requirements

### Requirement: Scripted idempotent website provisioning

The system SHALL provision the `nudgebar.io` website in Umami via its REST API using a non-interactive script that is safe to re-run.

#### Scenario: First run creates the website

- **WHEN** the provisioning script runs and no `nudgebar.io` website exists in Umami
- **THEN** it authenticates with admin credentials from server-side config and creates the website

#### Scenario: Re-run does not duplicate

- **WHEN** the provisioning script runs again and a `nudgebar.io` website already exists
- **THEN** it does not create a duplicate and exits successfully

### Requirement: Website-ID handoff

Provisioning SHALL write the created website-ID to a stable server-side path so the `website` change can inject it into the marketing page.

#### Scenario: Website-ID is emitted

- **WHEN** provisioning completes successfully
- **THEN** the Umami website-ID is written to a known server-side path in a parseable form
- **AND** the website-ID is not committed to the repository

### Requirement: Download event contract

The system SHALL define a custom conversion event named exactly `Download clicked` that the marketing site fires; optional `platform`/`cta` properties MAY be attached.

#### Scenario: Event is recorded

- **WHEN** a `Download clicked` event is sent to the provisioned `nudgebar.io` website
- **THEN** Umami records it as an event for that website, queryable in the dashboard
