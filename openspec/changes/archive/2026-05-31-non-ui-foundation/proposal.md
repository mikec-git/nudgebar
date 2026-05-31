## Why

Nudgebar needs a durable non-UI foundation before UI design work can proceed safely. The current SwiftPM prototype proves the concept, but the MVP needs a long-term macOS project structure, provider architecture, auth/security boundaries, local persistence, and a reliable alert engine that can support Google, Microsoft, CalDAV, scheduling APIs, and EventKit.

## What Changes

- Create the long-term native macOS project shape with an Xcode app target and local Swift package structure.
- Move core non-UI behavior into testable packages while keeping visual UI/design ownership available for Claude after the migration.
- Add provider architecture and real MVP provider clients for EventKit, Google Calendar, Microsoft Graph, CalDAV, Calendly, Cal.com, and Acuity.
- Add local-first auth and credential storage boundaries using public-client OAuth patterns and Keychain-backed secrets.
- Add durable state for settings, connected accounts, sync cursors, and alert state.
- Treat event data as a minimized, disposable rolling cache rather than canonical storage.
- Add an alert engine that plans, deduplicates, snoozes, dismisses, and schedules alerts from local provider data.
- Add high-quality unit, integration, and e2e verification using realistic fixtures and no live external service calls.
- Keep committed OpenSpec/project specs finalized and sanitized; do not commit archived working specs.

## Capabilities

### New Capabilities

- `macos-project-foundation`: Native macOS Xcode target, local package layout, build settings, resources, entitlements, and minimal compile wiring.
- `calendar-provider-sync`: Calendar provider connectors, normalized alert occurrences, polling/delta sync, fixture-based provider behavior, and cross-provider dedupe.
- `credential-security`: Provider auth flows, Keychain secret storage, non-sensitive preference boundaries, scope minimization, and spec sanitization expectations.
- `local-persistence`: Durable non-secret state for settings, accounts, sync cursors, alert state, and minimized disposable event cache handling.
- `alert-engine`: Alert planning, scheduling, dismiss/snooze state, lifecycle reconciliation, local notification backup, and deterministic alert behavior.

### Modified Capabilities

None.

## Impact

- Adds or restructures macOS project files, app resources, entitlements, and build scripts.
- Adds local Swift package modules for core, providers, auth, persistence, macOS support, and tests.
- Changes the current provider protocol shape into sync-capable provider clients.
- Adds dependencies only when justified for stable calendar/auth behavior, such as Microsoft MSAL or a proven CalDAV/iCalendar parser.
- Adds fixture-based unit, integration, and e2e tests that avoid live Google, Microsoft, CalDAV, Calendly, Cal.com, and Acuity calls.
- Coordinates with Claude UI work by completing migration/foundation first and preserving UI design as a separate implementation surface.
