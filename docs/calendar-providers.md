# Calendar Provider Strategy

Nudgebar should not be an EventKit-only app. EventKit is the fastest local connector for calendars already configured on the Mac, but the MVP should also support direct cloud providers, standards-based CalDAV servers, and scheduling APIs.

## MVP Providers

| Category | Examples | Best Use | Tradeoff |
| --- | --- | --- | --- |
| Local macOS calendars | Apple EventKit | Quick setup, no third-party credentials, works with accounts already in macOS | Limited to what the user configured in macOS |
| Direct cloud APIs | Google Calendar API, Microsoft Graph Calendar API | Reliable account-specific sync, change notifications, full event metadata | Requires OAuth apps, scopes, consent, token storage |
| Open standards | CalDAV | Covers iCloud, Fastmail, Nextcloud, Radicale, DAViCal, and custom servers | Provider quirks and credential handling |
| Scheduling platforms | Calendly, Cal.com, Acuity | Alerts for booked appointments that may not live in the user's main calendar yet | Usually not a full personal calendar replacement |

## MVP Connector Set

Build these before considering additional providers:

- `eventkit`: reads calendars already configured on macOS.
- `google_calendar`: uses Google Calendar API and OAuth.
- `microsoft_graph`: uses Microsoft Graph for Outlook.com, Microsoft 365, and Exchange Online calendars.
- `caldav`: standards connector for iCloud, Fastmail, Nextcloud, Radicale, DAViCal, and custom CalDAV servers.
- `calendly`: scheduling connector for booked and canceled meetings.
- `cal_com`: scheduling connector for Cal.com bookings.
- `acuity`: scheduling connector for Acuity appointments.

## Custom Calendar Software

Most custom calendar software falls into one of three integration shapes:

- It exposes CalDAV. Treat it as a CalDAV account.
- It exposes a scheduling API. Add it as a scheduling provider.
- It exposes a proprietary REST/GraphQL API. Add a provider module that maps its events into `AlertOccurrence`.

The provider contract in `Sources/NudgebarProviders/CalendarSyncProvider.swift` keeps those connectors behind the same discovery and sync interface.

## Notes From Primary Docs

- Google Calendar exposes event listing through the Calendar API.
- Microsoft exposes calendar events through Microsoft Graph.
- CalDAV is the standards-based calendar access protocol defined by RFC 4791.
- Apple EventKit is still useful for local macOS calendars and detects outside changes to the local Calendar database.
- Fastmail documents calendar access through CalDAV.
- Nextcloud calendar integrations use its CalDAV backend.
- Calendly, Cal.com, and Acuity expose scheduling/appointment APIs that can be useful alert sources even when they are not the user's canonical calendar.

## Implementation Order

1. Keep EventKit as the zero-configuration Mac connector.
2. Add direct Google Calendar OAuth.
3. Add direct Microsoft Graph OAuth.
4. Add generic CalDAV with Keychain-backed credentials.
5. Add scheduling app connectors for Calendly, Cal.com, and Acuity.

## Later Providers

Keep these out of the MVP unless a target user requires them:

- ICS/Webcal read-only subscriptions.
- Zoho Calendar.
- Unified brokers such as Nylas, Cronofy, or Morgen.
- Additional proprietary scheduling/calendar APIs.

## Official References

- Google Calendar API: https://developers.google.com/calendar/api/v3/reference/events/list
- Microsoft Graph calendar events: https://learn.microsoft.com/en-us/graph/api/calendar-list-events
- CalDAV RFC 4791: https://datatracker.ietf.org/doc/html/rfc4791
- Apple EventKit: https://developer.apple.com/documentation/eventkit
- Fastmail developer docs: https://www.fastmail.com/dev/
- Nextcloud calendar provider docs: https://docs.nextcloud.com/server/latest/developer_manual/digging_deeper/groupware/calendar_provider.html
- Calendly developer docs: https://developer.calendly.com/getting-started
- Cal.com bookings API: https://cal.com/docs/api-reference/v2/bookings/get-all-bookings
- Acuity appointments API: https://developers.acuityscheduling.com/reference/get-appointments
