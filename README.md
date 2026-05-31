# Nudgebar

Nudgebar is a native macOS menu-bar app for high-visibility calendar reminders. It is designed around pluggable calendar providers so it can read local macOS calendars, direct cloud calendar APIs, CalDAV servers, and scheduling apps.

## Current Scope

- Menu-bar app with no Dock icon when packaged.
- Local macOS calendar permission flow through EventKit.
- MVP provider catalog for EventKit, Google Calendar, Microsoft Graph, CalDAV, Calendly, Cal.com, and Acuity.
- Configurable reminder lead time.
- Configurable full-screen alerts.
- Calendar enable/disable controls.
- Test alert action for local verification.

The current running connector is EventKit. The provider contract and integration strategy are documented so direct Google, Microsoft, CalDAV, and scheduling connectors can be added without changing alert logic.

## Requirements

- macOS 13 or newer.
- Swift 5.9 or newer.
- Xcode Command Line Tools are enough for `swift build` and tests.

## Develop

```sh
swift build
swift test
swift run Nudgebar
```

Running with `swift run` is useful during development, but calendar privacy prompts work best from a bundled app because macOS reads usage descriptions from `Info.plist`.

## Package Locally

```sh
Scripts/package-app.sh
open dist/Nudgebar.app
```

The package script builds a release binary, creates `dist/Nudgebar.app`, and copies `Resources/Info.plist` into the bundle.

## Product Notes

The MVP scope is EventKit, Google Calendar, Microsoft Graph, CalDAV, and scheduling APIs. EventKit is one connector, not the product boundary. See `docs/calendar-providers.md` for the provider matrix and implementation order.
