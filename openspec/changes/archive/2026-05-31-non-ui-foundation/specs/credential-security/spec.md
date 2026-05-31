## ADDED Requirements

### Requirement: Public-client OAuth architecture
The system SHALL treat the macOS app as a public OAuth client and use Authorization Code with PKCE for supported OAuth providers unless a provider-specific library is selected.

#### Scenario: OAuth provider starts authorization
- **WHEN** the user connects an OAuth provider
- **THEN** the app starts a public-client authorization flow without embedding a client secret in the app bundle

#### Scenario: Microsoft auth uses approved native flow
- **WHEN** Microsoft Graph auth is implemented
- **THEN** the app uses MSAL or an equivalent native public-client flow that supports delegated calendar access and refresh

### Requirement: Keychain secret storage
The system SHALL store all long-lived provider secrets in macOS Keychain and SHALL NOT store those secrets in UserDefaults, local JSON, logs, fixtures, or committed specs.

#### Scenario: Refresh token is stored
- **WHEN** an OAuth provider returns a refresh token
- **THEN** the token is stored in Keychain and not in UserDefaults or plain local files

#### Scenario: CalDAV credential is stored
- **WHEN** a CalDAV account is configured
- **THEN** the password or app-specific password is stored in Keychain

#### Scenario: API key is stored
- **WHEN** a scheduling provider requires an API key or Basic Auth credential
- **THEN** the credential is stored in Keychain

### Requirement: Non-sensitive preference boundary
The system SHALL store only non-sensitive preferences outside Keychain.

#### Scenario: Preference is persisted
- **WHEN** the user changes alert lead time, full-screen mode, selected calendars, or enabled providers
- **THEN** the value may be stored in UserDefaults or another non-secret persistence layer

#### Scenario: Sensitive provider data is rejected from preferences
- **WHEN** persistence code attempts to save tokens, passwords, API keys, Basic Auth headers, PKCE verifiers, client secrets, raw event bodies, attendee lists, meeting links, or private notes outside Keychain
- **THEN** the implementation prevents or rejects that storage path

### Requirement: Scope minimization
The system SHALL request the minimum provider scopes needed for read-only alerting.

#### Scenario: Google scopes are requested
- **WHEN** Google Calendar auth is requested
- **THEN** the app requests read-only calendar list and event scopes unless a later requirement explicitly adds write behavior

#### Scenario: Microsoft scopes are requested
- **WHEN** Microsoft Graph auth is requested
- **THEN** the app starts with delegated calendar read scopes and offline access, avoiding application permissions for MVP

#### Scenario: Scheduling scopes are requested
- **WHEN** a scheduling provider supports scoped auth
- **THEN** the app requests booking/scheduled-event read scopes and avoids webhook write scopes until a backend relay exists

### Requirement: Sanitized logs and specs
The system SHALL prevent secrets and sensitive local context from being written to logs, test fixtures, committed OpenSpec specs, or project documentation.

#### Scenario: Spec secret scan runs
- **WHEN** OpenSpec or project specs are prepared for commit
- **THEN** a sanitizer or scan checks for tokens, credentials, device identifiers, local machine identifiers, addresses, account IDs, private URLs, raw logs, and other sensitive context
