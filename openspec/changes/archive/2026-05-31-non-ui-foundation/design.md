## Context

Nudgebar currently has a SwiftPM prototype for a macOS menu-bar calendar alert app. Claude is waiting on the long-term macOS project migration before continuing UI design work. The non-UI foundation must establish the native app structure, core package boundaries, provider sync model, auth/security model, local persistence model, and reliable alert engine before visual UI work resumes.

The MVP is a local-first macOS app with no backend. It supports EventKit, Google Calendar, Microsoft Graph Calendar, CalDAV, Calendly, Cal.com, and Acuity. Automated verification must not call live external providers.

## Goals / Non-Goals

**Goals:**

- Create a long-term Xcode macOS app target backed by local Swift packages.
- Keep core non-UI logic testable outside AppKit/SwiftUI views.
- Implement real provider clients behind a shared sync-capable interface.
- Persist durable non-secret state while storing secrets only in Keychain.
- Treat event data as a minimized disposable rolling cache.
- Build a reliable alert engine with dedupe, dismiss, snooze, lifecycle reconciliation, and local notification backup.
- Add unit, integration, and e2e tests that exercise realistic workflows with fixtures and local test services.

**Non-Goals:**

- Visual design, final UI layout, and visual polish.
- Cloud backend, webhook relay, remote push, or cross-device sync.
- Live provider calls in automated tests.
- Write-back/editing of provider events.
- ICS/Webcal, Zoho, Nylas, Cronofy, Morgen, or additional providers.
- Committing archived working specs.

## Decisions

### Use an Xcode app target plus local Swift packages

The app bundle, entitlements, assets, signing, launch-at-login, UI tests, archive/export, and notarization belong in an Xcode macOS app target. Core logic belongs in local Swift packages so it remains easy to test and safe for multiple agents to edit.

Alternative considered: keep pure SwiftPM packaging. This was rejected for the long-term MVP because entitlement, bundle, signing, and UI test needs would become fragile.

### Keep SwiftUI for app surfaces and AppKit for full-screen alert windows

SwiftUI is appropriate for menu-bar/settings/onboarding surfaces. Full-screen alert presentation needs AppKit control over windows, Spaces, activation, multi-monitor behavior, and window levels.

Alternative considered: implement all alert presentation in SwiftUI. This was rejected because SwiftUI alone does not expose enough control for reliable overlay behavior.

### Use provider connectors plus a canonical alert occurrence model

Each provider maps raw events/bookings into a shared `AlertOccurrence` model. The alert engine consumes only normalized occurrences and provider metadata, not provider-specific payloads.

Alternative considered: let alert logic branch on provider-specific event models. This was rejected because it would duplicate behavior and make dedupe/testing brittle.

### Use polling and provider delta mechanisms for MVP

The local app should use EventKit change notifications, Google sync tokens, Microsoft delta links, CalDAV sync tokens/ETags, and scheduling API polling. Webhooks require a public HTTPS receiver and are therefore not part of the local-only MVP.

Alternative considered: build webhooks first. This was rejected because it implies backend infrastructure and does not fit the MVP ownership boundary.

### Persist durable state, but treat event data as disposable cache

Settings, account metadata, sync cursors, and alert state must survive app restarts. Event data should be cached only for a rolling alert window, minimized to fields needed for alerting, and rebuilt from providers when stale or invalid.

Alternative considered: store all raw provider event payloads. This was rejected for privacy and desync risk.

### Use Keychain for secrets and UserDefaults/config files only for non-sensitive state

OAuth refresh tokens, API keys, CalDAV passwords, and Basic Auth credentials must be stored in Keychain. UserDefaults and local files may store non-sensitive preferences, selected calendar IDs, provider IDs, sync metadata, and alert state.

Alternative considered: store tokens in UserDefaults for speed. This was rejected for security.

## Risks / Trade-offs

- Provider implementation breadth is large for one task -> keep UI out of scope and use fixtures/local services for automated tests.
- CalDAV behavior varies by server -> implement standards-first behavior with explicit fallback paths and fixture coverage for common server patterns.
- Microsoft/Google auth setup can be delayed by provider app registration -> define public-client auth adapters and test token handling with fixtures.
- Event dedupe can suppress legitimate separate events -> group duplicates for alerting without deleting provider-specific source records.
- AppKit overlay behavior can vary across Spaces, displays, and Focus modes -> use e2e/local smoke tests and lifecycle reconciliation.
- Xcode project files can create merge conflicts -> keep UI work paused until migration is done and keep packages as the main editing surface.

## Migration Plan

1. Create the Xcode app target and local package structure.
2. Move current core models/policies into package modules.
3. Keep minimal app wiring compiling with existing menu-bar behavior where practical.
4. Add persistence and credential abstractions.
5. Add provider connector implementations and fixture tests.
6. Add alert engine state/planning/scheduling.
7. Add integration and e2e tests using local fixtures and no live provider calls.
8. Run OpenSpec validation and spec secret scan before any commit.

Rollback strategy: keep the current SwiftPM prototype files available until the Xcode target and packages build. If migration fails, preserve the prototype branch and revert only the migration commit rather than deleting source files manually.

## Open Questions

- Final bundle identifier and Apple Developer Team ID.
- Whether SQLite is needed before beta or whether JSON/UserDefaults-backed persistence is enough behind the abstraction.
- Exact e2e harness shape for the macOS app target once Xcode is installed and healthy locally.
