# macOS Architecture

Nudgebar's MVP should be a native Swift macOS app. The product depends on Mac-specific behavior: menu-bar presence, calendar permissions, Keychain storage, full-screen alert windows, and local EventKit access. Swift keeps those integrations direct and avoids a heavy desktop wrapper for the first version.

## MVP Stack

- Xcode macOS app target for the bundle, entitlements, assets, UI tests, signing, archive/export, and notarization.
- Local Swift packages for core logic, provider normalization, auth models, persistence, and tests.
- SwiftUI for menu-bar, settings, and alert views.
- AppKit where SwiftUI does not expose enough control, especially full-screen alert windows and app activation behavior.
- EventKit for the local macOS calendar connector.
- URLSession-based provider clients for Google Calendar, Microsoft Graph, CalDAV, and scheduling APIs.
- Keychain for OAuth tokens and CalDAV/API credentials.
- UserDefaults for non-sensitive local preferences.

## App Shape

- `NudgebarApp`: app entry point and menu-bar scene.
- `AppModel`: shared application state and event monitor startup.
- `CalendarProviderClient`: common connector interface for local, cloud, CalDAV, and scheduling providers.
- `AlertPolicy`: deterministic logic for deciding which events should trigger alerts.
- `AlertPresenter`: native macOS alert presentation, including full-screen mode.
- `SyncCoordinator`: provider refresh, event normalization, and cache updates.
- `AlertScheduler`: one-shot alert timers plus lifecycle reconciliation.
- `CredentialStore`: Keychain-backed storage for OAuth tokens, API keys, and CalDAV credentials.

## Non-MVP Technology

Do not start with Electron, Tauri, React Native macOS, or a custom web shell. Those can be reconsidered only if the product needs a cross-platform client or a much richer settings surface than native SwiftUI can support.

If a web UI becomes useful later, keep Swift as the Mac host and embed the web surface behind native storage, calendar, and alerting services.
