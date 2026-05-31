import Foundation

enum CalendarProviderKind: String, CaseIterable, Identifiable {
    case eventKit = "eventkit"
    case googleCalendar = "google_calendar"
    case microsoftGraph = "microsoft_graph"
    case caldav = "caldav"
    case calendly = "calendly"
    case calCom = "cal_com"
    case acuity = "acuity"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .eventKit:
            return "macOS Calendar"
        case .googleCalendar:
            return "Google Calendar"
        case .microsoftGraph:
            return "Microsoft Outlook / Exchange"
        case .caldav:
            return "CalDAV"
        case .calendly:
            return "Calendly"
        case .calCom:
            return "Cal.com"
        case .acuity:
            return "Acuity Scheduling"
        }
    }
}

enum CalendarProviderCapability: String, Hashable {
    case readEvents
    case writeEvents
    case recurringEvents
    case availability
    case reminders
    case webhooks
    case localSystemCalendars
}

enum CalendarProviderAuthMode: String {
    case macOSPrivacy
    case oauth2
    case caldavCredentials
    case apiToken
}

struct CalendarProviderDescriptor: Equatable, Identifiable {
    let kind: CalendarProviderKind
    let authMode: CalendarProviderAuthMode
    let capabilities: Set<CalendarProviderCapability>
    let documentationURL: URL
    let notes: String

    var id: String {
        kind.id
    }
}

protocol CalendarProviderClient {
    var descriptor: CalendarProviderDescriptor { get }

    func requestAccess() async throws
    func listCalendars() async throws -> [CalendarSource]
    func events(
        from startDate: Date,
        to endDate: Date,
        calendarIDs: Set<String>
    ) async throws -> [AlertCandidate]
}

enum CalendarProviderCatalog {
    static let mvpProviderKinds: [CalendarProviderKind] = [
        .eventKit,
        .googleCalendar,
        .microsoftGraph,
        .caldav,
        .calendly,
        .calCom,
        .acuity
    ]

    static let providers: [CalendarProviderDescriptor] = [
        CalendarProviderDescriptor(
            kind: .eventKit,
            authMode: .macOSPrivacy,
            capabilities: [.readEvents, .writeEvents, .recurringEvents, .reminders, .localSystemCalendars],
            documentationURL: URL(string: "https://developer.apple.com/documentation/eventkit")!,
            notes: "Local connector for calendars already configured in macOS."
        ),
        CalendarProviderDescriptor(
            kind: .googleCalendar,
            authMode: .oauth2,
            capabilities: [.readEvents, .writeEvents, .recurringEvents, .availability, .reminders, .webhooks],
            documentationURL: URL(string: "https://developers.google.com/calendar/api/v3/reference/events/list")!,
            notes: "Direct Google connector for users who do not want to rely on macOS account sync."
        ),
        CalendarProviderDescriptor(
            kind: .microsoftGraph,
            authMode: .oauth2,
            capabilities: [.readEvents, .writeEvents, .recurringEvents, .availability, .reminders, .webhooks],
            documentationURL: URL(string: "https://learn.microsoft.com/en-us/graph/api/calendar-list-events")!,
            notes: "Direct Outlook.com, Microsoft 365, and Exchange Online connector through Graph."
        ),
        CalendarProviderDescriptor(
            kind: .caldav,
            authMode: .caldavCredentials,
            capabilities: [.readEvents, .writeEvents, .recurringEvents, .availability],
            documentationURL: URL(string: "https://datatracker.ietf.org/doc/html/rfc4791")!,
            notes: "Standards connector for iCloud, Fastmail, Nextcloud, Radicale, DAViCal, and custom CalDAV servers."
        ),
        CalendarProviderDescriptor(
            kind: .calendly,
            authMode: .oauth2,
            capabilities: [.readEvents, .webhooks],
            documentationURL: URL(string: "https://developer.calendly.com/getting-started")!,
            notes: "Scheduling connector for booked and canceled meetings, not a full personal calendar backend."
        ),
        CalendarProviderDescriptor(
            kind: .calCom,
            authMode: .apiToken,
            capabilities: [.readEvents, .writeEvents, .webhooks],
            documentationURL: URL(string: "https://cal.com/docs/api-reference/v2/bookings/get-all-bookings")!,
            notes: "Scheduling connector for Cal.com bookings and event types."
        ),
        CalendarProviderDescriptor(
            kind: .acuity,
            authMode: .apiToken,
            capabilities: [.readEvents, .writeEvents, .webhooks],
            documentationURL: URL(string: "https://developers.acuityscheduling.com/reference/get-appointments")!,
            notes: "Appointment-booking connector for Acuity calendars."
        )
    ]
}
