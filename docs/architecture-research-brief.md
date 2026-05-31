# Architecture Research Brief

This brief consolidates five parallel research passes for Nudgebar's MVP architecture. It is intended to be handed to Claude for product and technical design.

## Product Scope

Nudgebar is a native macOS menu-bar app that shows configurable full-screen calendar alerts.

MVP provider scope:

- EventKit for local macOS calendars.
- Google Calendar API.
- Microsoft Graph Calendar API.
- CalDAV.
- Scheduling APIs, starting with Calendly, Cal.com, and Acuity.

Non-MVP:

- ICS/Webcal.
- Zoho Calendar.
- Nylas/Cronofy/Morgen broker layer.
- Cloud webhook relay.
- Cross-device sync.

## Top-Level Recommendation

Use a native Swift macOS app with an Xcode app target and local Swift packages:

- Xcode macOS app target for app bundle, entitlements, assets, UI tests, signing, archive/export, and notarization.
- SwiftUI for menu bar, settings, and alert views.
- AppKit for full-screen overlay windows, activation behavior, Spaces, and multi-monitor control.
- Local Swift packages for core alert logic, provider normalization, sync, auth models, persistence, and tests.
- Local-first architecture with no backend for MVP.
- Polling and provider delta sync for MVP; no webhooks until there is a backend/relay.

## Proposed Repo Structure

```text
nudgebar/
  Nudgebar.xcodeproj/
  App/Nudgebar/
    NudgebarApp.swift
    UI/
    Alerts/
    Settings/
    Resources/Info.plist
    Resources/Assets.xcassets
    Nudgebar.entitlements
  Packages/NudgebarKit/
    Package.swift
    Sources/NudgebarCore/
    Sources/NudgebarProviders/
    Sources/NudgebarAuth/
    Sources/NudgebarPersistence/
    Sources/NudgebarMacSupport/
    Tests/
  Scripts/
    build.sh
    package-dmg.sh
    notarize.sh
  docs/
    architecture-research-brief.md
    macos-architecture.md
    calendar-providers.md
    design/
  .github/workflows/
    ci.yml
```

## Core Modules

- `AppHost`: SwiftUI app entry point, menu-bar scene, settings scene, app delegate, activation policy.
- `Presentation`: menu-bar UI, settings UI, onboarding/auth UI, alert views.
- `Windowing`: AppKit full-screen overlay manager using `NSWindow`, `NSHostingView`, `NSScreen`, window levels, and collection behavior.
- `Providers`: one connector per provider: EventKit, Google, Microsoft, CalDAV, Calendly, Cal.com, Acuity.
- `SyncCoordinator`: runs provider sync jobs, persists normalized occurrences, and triggers alert replanning.
- `EventCache`: local normalized event/occurrence cache.
- `AlertPlanner`: deterministic logic converting occurrences into alert due times.
- `AlertScheduler`: one-shot timer for next alert plus reconciliation after lifecycle changes.
- `AlertStateStore`: persistent dismiss/snooze/dedupe state.
- `AuthCoordinator`: starts provider auth, handles callback, refresh, and disconnect.
- `CredentialStore`: Keychain-only secret storage.
- `PrivacyPolicy`: rules for logging, local cache redaction, and alert display privacy.

## Calendar Sync Architecture

Use one canonical `AlertOccurrence` model. Providers normalize their raw events/bookings into this model.

MVP sync approach:

- EventKit: listen to `EKEventStoreChangedNotification`, then refetch a rolling window because EventKit only reports that something changed.
- Google: use `events.list` with `singleEvents=true`, persist `nextSyncToken`, and do a full resync if Google returns `410 Gone`.
- Microsoft: use `calendarView/delta` per calendar/date window and persist `@odata.deltaLink`.
- CalDAV: discover calendar collections, prefer WebDAV `sync-collection` with `DAV:sync-token`, and fall back to bounded `calendar-query` plus `ETag` diffing.
- Scheduling APIs: treat bookings as alert-only sources, not full calendar replacements. Poll upcoming/changed bookings and map cancel/reschedule events to deleted/replaced occurrences.

Do not build webhooks into the MVP local app. Google, Microsoft, Calendly, Cal.com, and Acuity webhooks need a publicly reachable HTTPS receiver. Add a cloud relay later if needed.

## MVP Event Model

Minimum useful fields:

- Internal: `id`, `accountID`, `providerKind`, `sourceID`, `sourceName`, `sourceColor`, `enabled`.
- Provider identity: `providerEventID`, `providerOccurrenceID`, `providerSeriesID`, `iCalUID`, `recurrenceOriginalStart`.
- Time: `startAt`, `endAt`, `timeZoneID`, `isAllDay`, `isFloatingTime`.
- Display: `title`, `location`, `meetingURL`, `notesPreview`.
- State: `status`, `availability`, `visibility`, `selfResponseStatus`.
- Sync metadata: `etag`, `version`, `updatedAt`, `sequence`, `rawHash`.
- Alert state: `alertAt`, `alertPolicyID`, `dismissedAt`, `snoozedUntil`, `lastAlertedAt`.

Use provider-expanded occurrences whenever possible. For CalDAV recurrence, use a proven iCalendar/RRULE parser rather than hand-rolling recurrence behavior.

## Dedupe Strategy

Primary identity should be provider-local:

```text
providerKind:accountID:calendarID:eventUID:occurrenceStart
```

For cross-provider alert dedupe, group duplicates rather than overwriting events.

Preferred dedupe keys:

1. `iCalUID + occurrenceStart`.
2. Known external calendar reference from a scheduling provider.
3. Normalized meeting URL.
4. Fallback fuzzy key: normalized title + start + end + organizer/location.

If the same event appears through EventKit and a direct provider, prefer the direct provider for alert display and suppress the duplicate.

## Alert Engine Architecture

Do not rely on provider polling alone. Keep a local event cache, persist alert state, and schedule the next alert from local data.

Recommended components:

- `ProviderSyncManager`: provider refresh.
- `EventCache`: normalized occurrence cache, likely `now - 1h` to `now + 14d` for active alerting.
- `AlertPlanner`: pure function that computes `alertAt = event.start - leadTime`.
- `AlertStateStore`: persistent dismiss/snooze/dedupe state, preferably SQLite or atomic JSON for early MVP.
- `AlertScheduler`: one active one-shot wall-clock timer for the next alert, plus periodic safety reconciliation.
- `PresentationCoordinator`: opens full-screen AppKit windows or falls back to a panel/local notification.
- `NotificationBackupScheduler`: schedules local notifications for a small set of upcoming alerts as backup.

Lifecycle reconciliation triggers:

- App launch and termination.
- EventKit change notifications.
- Sleep/wake.
- Screen wake.
- User session active/inactive changes.
- Display configuration changes.
- Active Space changes while a full-screen alert is showing.
- System clock/time-zone/calendar-day changes.
- Network return through `NWPathMonitor`.

Local notifications are backup only. Full-screen windows are the primary experience while the app is running, but macOS notifications may be delayed, suppressed by Focus, or not delivered.

## Alert State Model

Use a canonical `alertKey`:

```text
providerKind:accountID:calendarID:eventUID:occurrenceStart:alertOffset
```

Persist:

- `alertKey`
- `dedupeKey`
- `eventFingerprint`
- `status`: `pending`, `presented`, `snoozed`, `dismissed`, `expired`
- `firstPresentedAt`
- `lastPresentedAt`
- `dismissedAt`
- `snoozeUntil`
- `occurrenceStart`
- `eventEnd`
- `providerUpdatedAt` / `etag` / version
- `expiresAt`

Rules:

- Dismiss suppresses the same occurrence until after event end plus retention.
- Snooze re-arms the same occurrence at `snoozeUntil`.
- If an event moves materially, recompute and allow a new alert unless the user dismissed after that provider version.

## Auth And Credential Architecture

Treat Nudgebar as a public OAuth client. Native apps cannot protect client secrets.

Use:

- Authorization Code + PKCE for Google, Calendly, and Cal.com OAuth.
- MSAL for Microsoft Graph where practical.
- `ASWebAuthenticationSession` for browser-based OAuth on macOS.
- HTTPS-only CalDAV credentials, preferably app-specific passwords.
- Acuity User ID + API key / Basic Auth for MVP; its OAuth flow requires a client secret, so public Acuity OAuth needs a later backend broker.
- Keychain for every long-lived credential.

Credential storage:

- Keychain: refresh tokens, persisted access tokens, API keys, CalDAV passwords, Acuity credentials, webhook signing keys.
- UserDefaults: alert lead time, full-screen enabled/disabled, selected calendar IDs, enabled provider IDs, non-sensitive UI preferences.

Never store tokens, API keys, passwords, Basic Auth headers, PKCE verifiers, client secrets, raw event bodies, attendee lists, meeting links, or private notes in UserDefaults.

Minimum scopes:

- Google: `calendar.calendarlist.readonly` and `calendar.events.readonly`.
- Microsoft: start with delegated `Calendars.ReadBasic`; use `Calendars.Read` only if richer details are needed; include `offline_access`.
- Calendly: `scheduled_events:read`, `users:read`; `webhooks:write` only after a relay exists.
- Cal.com: `BOOKING_READ`, optional `PROFILE_READ`; `WEBHOOK_WRITE` later.
- Acuity: Basic Auth/API key is broad, so make that risk explicit in UI.

## Packaging And Distribution

Use an Xcode app target for the real app bundle. SwiftPM alone is not enough once entitlements, signing, UI tests, archive/export, and notarization matter.

MVP path:

- Replace `com.local.Nudgebar` with a real reverse-DNS bundle ID.
- Keep `LSUIElement=true` for no Dock icon.
- Keep `NSCalendarsFullAccessUsageDescription`.
- Add entitlements when sandboxed:
  - `com.apple.security.app-sandbox`
  - `com.apple.security.network.client`
  - `com.apple.security.personal-information.calendars`
- Add launch-at-login through `SMAppService.mainApp.register()` on macOS 13+.
- Use Developer ID signing, hardened runtime, notarization, and a `.dmg` or `.zip` for external testers.
- Start with manual private GitHub Releases/downloads; consider Sparkle 2 later.

Release checks:

- `codesign --verify --deep --strict`
- `spctl --assess`
- `xcrun stapler validate`
- Manual launch from installed DMG.

## Testing Strategy

- Unit tests in local Swift packages for alert policy, event normalization, dedupe, provider pagination, retry/backoff, token expiry, and preference logic.
- Integration tests with fixture HTTP servers for Google, Microsoft, CalDAV, and scheduling APIs.
- Fake EventKit adapter in CI; real EventKit permissions as manual bundled-app smoke tests.
- UI tests through Xcode/XCTest with launch flags such as `--use-fixtures`, `--reset-state`, and `--disable-real-providers`.
- GitHub Actions on pinned macOS/Xcode runners once the Xcode project exists.

## Key Risks

- Full-screen alerts are intentionally intrusive; design needs clear dismiss, snooze, disable full-screen, privacy, and quiet-mode controls.
- Duplicate events are likely when users connect both EventKit and direct providers.
- CalDAV servers vary widely in auth, discovery, sync-token support, recurrence behavior, and ETag semantics.
- OAuth verification, Microsoft tenant consent, and scheduling API quirks may slow public distribution.
- Webhooks require a backend relay; do not depend on them for local MVP reliability.
- Signing/notarization automation requires Apple Developer credentials and careful CI secret handling.

## Recommended Claude Design Prompt

Design the MVP architecture for Nudgebar, a native macOS menu-bar app that shows configurable full-screen calendar alerts. Use Swift, SwiftUI, AppKit, an Xcode app target, and local Swift packages. The app should be local-first with no backend for MVP.

MVP providers are EventKit, Google Calendar, Microsoft Graph, CalDAV, Calendly, Cal.com, and Acuity. Design provider connectors that normalize events/bookings into a canonical `AlertOccurrence` cache. Use polling and provider delta sync, not webhooks. Use Keychain for secrets and UserDefaults only for non-sensitive preferences. Use AppKit windows for full-screen alerts and local notifications only as backup.

Produce:

- Target repo/project structure.
- Main modules and responsibilities.
- Data model for accounts, sources, occurrences, sync state, alert state, and preferences.
- Provider sync strategy.
- Auth and credential strategy.
- Alert scheduling/reconciliation design.
- Settings/onboarding design surfaces.
- Testing and packaging plan.
- MVP milestones in implementation order.

## Official References

- Apple MenuBarExtra: https://developer.apple.com/documentation/swiftui/menubarextra
- Apple Settings: https://developer.apple.com/documentation/swiftui/settings
- Apple AppKit: https://developer.apple.com/documentation/AppKit
- Apple NSWindow: https://developer.apple.com/documentation/AppKit/NSWindow
- Apple LSUIElement: https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement
- Apple EventKit: https://developer.apple.com/documentation/eventkit/ekeventstore
- Apple EventKit notifications: https://developer.apple.com/documentation/eventkit/updating-with-notifications
- Apple ASWebAuthenticationSession: https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession
- Apple Keychain Services: https://developer.apple.com/documentation/security/keychain_services
- Apple Service Management: https://developer.apple.com/documentation/servicemanagement/
- Apple notarization: https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution
- Google Calendar sync: https://developers.google.com/workspace/calendar/api/guides/sync
- Google OAuth native apps: https://developers.google.com/identity/protocols/oauth2/native-app
- Google Calendar auth scopes: https://developers.google.com/workspace/calendar/api/auth
- Microsoft Graph event delta: https://learn.microsoft.com/en-us/graph/delta-query-events
- Microsoft MSAL macOS: https://learn.microsoft.com/en-us/entra/msal/objc/install-and-configure-msal
- CalDAV RFC 4791: https://www.rfc-editor.org/rfc/rfc4791.html
- WebDAV sync RFC 6578: https://www.rfc-editor.org/rfc/rfc6578
- iCalendar RFC 5545: https://www.rfc-editor.org/rfc/rfc5545
- Calendly scopes: https://developer.calendly.com/scopes
- Calendly refresh token rotation: https://developer.calendly.com/refresh-token-rotation-guide
- Cal.com OAuth: https://cal.com/docs/api-reference/v2/oauth
- Acuity OAuth: https://developers.acuityscheduling.com/docs/oauth2
- Acuity appointments: https://developers.acuityscheduling.com/reference/get-appointments
- Sparkle: https://sparkle-project.github.io/documentation/
