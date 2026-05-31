# Nudgebar

Nudgebar is a native macOS menu-bar app for high-visibility calendar reminders. It is designed around pluggable calendar providers so it can read local macOS calendars, direct cloud calendar APIs, CalDAV servers, and scheduling apps.

## Current Scope

- Xcode macOS app target with local Swift package modules for non-UI behavior.
- Menu-bar app with no Dock icon when packaged.
- Local macOS calendar permission flow through EventKit.
- MVP provider catalog for EventKit, Google Calendar, Microsoft Graph, CalDAV, Calendly, Cal.com, and Acuity.
- Offline fixture connectors for direct calendar and scheduling providers.
- Keychain-backed credential boundary and non-secret local persistence.
- Alert planning, dedupe, dismiss, snooze, one-shot scheduling, lifecycle reconciliation, and backup notification primitives.
- Configurable reminder lead time.
- Configurable full-screen alerts.
- Calendar enable/disable controls.
- Test alert action for local verification.

The current running connector is EventKit. Direct Google, Microsoft, CalDAV, and scheduling connectors are represented behind sync-capable boundaries with fixture-backed tests so alert logic does not depend on provider-specific payloads.

## Requirements

- macOS 13 or newer.
- Swift 6.0 or newer.
- Full Xcode is required for `xcodebuild`; SwiftPM runs package tests when the local Swift toolchain and SDK match.

## Develop

```sh
make xcode-build
make swift-test
swift run Nudgebar
```

Running with `swift run` is useful during development, but calendar privacy prompts work best from a bundled app because macOS reads usage descriptions from `Info.plist`.

See `docs/build-and-test.md` for the full verification command list and local toolchain notes.

## Package Locally

```sh
Scripts/package-app.sh
open dist/Nudgebar.app
```

The package script builds a release binary, creates `dist/Nudgebar.app`, and copies `Resources/Info.plist` into the bundle.

## Product Notes

The MVP scope is EventKit, Google Calendar, Microsoft Graph, CalDAV, and scheduling APIs. EventKit is one connector, not the product boundary. See `docs/calendar-providers.md` for the provider matrix and implementation order.
