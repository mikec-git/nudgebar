## 1. Project Foundation

- [x] 1.1 Create an Xcode macOS app target for Nudgebar with app resources, Info.plist, entitlements, and minimal launchable wiring.
- [x] 1.2 Create local Swift package structure for core, providers, auth, persistence, macOS support, and tests.
- [x] 1.3 Move current reusable models and alert policy code into package modules without changing visual UI design.
- [x] 1.4 Wire the app target to the local packages and keep a minimal menu-bar app compiling.
- [x] 1.5 Add build scripts or documented commands for Xcode target builds and package tests.

## 2. Core Models And Provider Contracts

- [x] 2.1 Define account, source, sync state, alert occurrence, alert group, and provider identity models.
- [x] 2.2 Define sync-capable provider protocols for discovery, initial sync, incremental or polling sync, cancellation/deletion handling, and normalization.
- [x] 2.3 Add provider registry entries for EventKit, Google Calendar, Microsoft Graph Calendar, CalDAV, Calendly, Cal.com, and Acuity.
- [x] 2.4 Implement cross-provider dedupe keys and grouping behavior for alert presentation.
- [x] 2.5 Add behavior-focused unit tests for normalization and dedupe using realistic fixtures.

## 3. Auth And Credential Security

- [x] 3.1 Add Keychain-backed credential storage for OAuth tokens, CalDAV passwords, API keys, and Basic Auth credentials.
- [x] 3.2 Add auth adapter boundaries for public-client OAuth with PKCE and provider-specific auth metadata.
- [x] 3.3 Add Microsoft Graph auth integration using MSAL or a documented native public-client equivalent.
- [x] 3.4 Add CalDAV credential handling with HTTPS-only validation and app-password support.
- [x] 3.5 Add Acuity API key or Basic Auth credential handling without embedding client secrets.
- [x] 3.6 Add tests proving secrets are not stored in UserDefaults, local JSON, logs, fixtures, or committed specs.

## 4. Persistence

- [x] 4.1 Add persistence interfaces for settings, connected account metadata, source selections, sync cursors, alert state, and disposable event cache.
- [x] 4.2 Implement durable settings persistence for alert lead time, full-screen mode, enabled providers, and selected calendars/sources.
- [x] 4.3 Implement durable account/source metadata persistence without storing secrets outside Keychain.
- [x] 4.4 Implement durable sync cursor persistence for Google, Microsoft, CalDAV, EventKit refresh metadata, and scheduling provider polling metadata.
- [x] 4.5 Implement durable alert state persistence for presented, dismissed, snoozed, and expired alerts.
- [x] 4.6 Implement minimized disposable event cache behavior with cache invalidation and rebuild paths.

## 5. Provider Implementations

- [x] 5.1 Implement EventKit connector with permission handling, source discovery, rolling-window fetch, and change-notification refresh.
- [x] 5.2 Implement Google Calendar connector with read-only scopes, expanded event occurrence sync, sync token persistence, and full-resync fallback.
- [x] 5.3 Implement Microsoft Graph Calendar connector with delegated calendar read scopes, calendar view delta sync, and delta link persistence.
- [x] 5.4 Implement CalDAV connector with account discovery, calendar collection discovery, sync-token or ETag refresh, and recurrence-safe occurrence handling.
- [x] 5.5 Implement Calendly connector for scheduled-event or booking alert sources using OAuth or token fixtures.
- [x] 5.6 Implement Cal.com connector for booking alert sources using OAuth or API-key fixtures.
- [x] 5.7 Implement Acuity connector for appointment alert sources using API-key or Basic Auth fixtures.
- [x] 5.8 Add fixture-based integration tests for all provider connectors without live external service calls.

## 6. Alert Engine

- [x] 6.1 Implement alert planner that computes due alerts from normalized occurrences and user preferences.
- [x] 6.2 Implement alert state transitions for pending, presented, snoozed, dismissed, and expired alerts.
- [x] 6.3 Implement one-shot alert scheduling from local state plus reconciliation after cache, setting, or provider updates.
- [x] 6.4 Add lifecycle reconciliation hooks for launch, wake, network return, time-zone changes, display changes, and EventKit changes.
- [x] 6.5 Add presentation request output for AppKit full-screen alert UI without owning final visual design.
- [x] 6.6 Add local notification backup scheduling for a limited upcoming alert window.
- [x] 6.7 Add deterministic unit and integration tests for alert planning, dismiss, snooze, dedupe, and lifecycle reconciliation.

## 7. E2E Verification And Handoff

- [x] 7.1 Add e2e or high-level integration fixture mode that exercises connect, sync, alert plan, dismiss, snooze, restart, and resync workflows without live provider calls.
- [x] 7.2 Run Xcode build/test commands and Swift package tests on the migrated project.
- [x] 7.3 Run fixture-based provider tests and alert workflow tests.
- [x] 7.4 Run spec sanitization checks before any commit containing OpenSpec/project specs.
- [x] 7.5 Update implementation handoff with scope completed, tests run, known limitations, and explicit UI handoff notes for Claude.
