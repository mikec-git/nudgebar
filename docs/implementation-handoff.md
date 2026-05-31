# Non-UI Foundation Handoff

## Scope Completed

- Added an Xcode macOS app project wrapper with bundle metadata, resources, entitlements, and a shared app scheme.
- Split reusable logic into local package modules for core models, provider sync, auth, persistence, and macOS support.
- Moved alert candidate/policy behavior into `NudgebarCore` and kept the app UI as minimal compile wiring.
- Added provider registry entries and fixture connectors for EventKit, Google Calendar, Microsoft Graph Calendar, CalDAV, Calendly, Cal.com, and Acuity.
- Added Keychain credential storage, OAuth PKCE metadata, HTTPS credential validation, and non-secret persistence guards.
- Added durable persistence interfaces and JSON/UserDefaults implementations for settings, accounts, sources, cursors, alert state, and disposable event cache.
- Added alert planning, cross-provider dedupe, dismiss/snooze state, one-shot scheduling, lifecycle reconciliation, presentation request output, and local notification backup support.
- Added offline unit/integration/e2e-style tests for provider fixtures and alert workflows.
- Added spec/doc sanitization scanning.

## Verification

- `xcode-select -p`: `/Applications/Xcode.app/Contents/Developer`.
- `xcodebuild -version`: Xcode 26.5, build 17F42.
- `xcodebuild -runFirstLaunch`: installed required first-launch content after Xcode installation.
- `make xcode-build`: passed.
- `make swift-test`: passed, 23 XCTest cases.
- `swift test --filter NudgebarProvidersTests`: passed, 6 XCTest cases.
- `swift test --filter NudgebarWorkflowTests`: passed, 1 XCTest case.
- `make sanitize-specs`: passed.
- `openspec archive non-ui-foundation --yes`: passed; archived to `openspec/changes/archive/2026-05-31-non-ui-foundation` and created canonical specs.
- `openspec validate --all --strict`: passed, 5 specs.

## Known Limitations

- Real network clients for Google, Microsoft, CalDAV, Calendly, Cal.com, and Acuity are represented by fixture-backed connector boundaries. Automated tests stay offline.
- Microsoft auth metadata is present for native public-client flow integration, but MSAL is not vendored yet.
- The Xcode project is created manually and now builds locally with Xcode 26.5.

## UI Handoff Notes For Claude

- Visual design remains in `Sources/Nudgebar` and should continue from the Xcode app target.
- Non-UI packages should be treated as the app-facing contract for alerts, providers, auth, and persistence.
- Full-screen alert visual polish can use `AlertPresentationRequest` from `NudgebarCore` without provider-specific branching.
