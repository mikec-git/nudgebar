# macos-project-foundation Specification

## Purpose
TBD - created by archiving change non-ui-foundation. Update Purpose after archive.
## Requirements
### Requirement: Native macOS app target
The system SHALL provide an Xcode macOS app target for Nudgebar that owns the app bundle, resources, entitlements, signing configuration, and launchable application entry point.

#### Scenario: Xcode app builds
- **WHEN** the developer runs the documented Xcode build command
- **THEN** the app target builds successfully without requiring live calendar provider credentials

#### Scenario: App target owns bundle metadata
- **WHEN** the app bundle is produced
- **THEN** bundle metadata, calendar usage descriptions, menu-bar app configuration, and entitlements are sourced from the app target resources

### Requirement: Local Swift package boundaries
The system SHALL keep reusable non-UI logic in local Swift packages with explicit modules for core models, provider sync, auth, persistence, and macOS support.

#### Scenario: Core package tests run independently
- **WHEN** package tests are executed
- **THEN** core alert, provider, auth, and persistence behavior is testable without launching the macOS app UI

#### Scenario: Package modules avoid UI layout ownership
- **WHEN** non-UI modules are changed
- **THEN** visual UI design and layout files are not required to change except for minimal compile wiring

### Requirement: Claude UI handoff boundary
The system SHALL preserve Claude's UI ownership by limiting this change to project migration, non-UI packages, provider/auth/persistence/alert logic, and compile-time wiring.

#### Scenario: UI design remains available after migration
- **WHEN** the non-UI foundation migration is complete
- **THEN** Claude can continue UI work from the Xcode app target without first undoing non-UI structural changes

### Requirement: Sanitized finalized specs
The project SHALL allow finalized OpenSpec/project specs to be committed only after sanitization and SHALL avoid committing archived working specs.

#### Scenario: Spec files are reviewed before commit
- **WHEN** a commit includes OpenSpec or project spec files
- **THEN** the files have been reviewed for secrets, sensitive context, device identifiers, local machine identifiers, addresses, private infrastructure details, account IDs, private URLs, and raw logs

#### Scenario: Archived working specs are excluded
- **WHEN** a working spec has been archived for local reference
- **THEN** the archived working spec is not included in the implementation commit

