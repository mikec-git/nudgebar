import NudgebarAuth
import NudgebarCore
import NudgebarProviders
import Foundation

/// Real Google Calendar API v3 client. Network calls use a refreshed OAuth access
/// token; response decoding lives in the pure, unit-tested `GoogleCalendarMapper`.
final class GoogleCalendarProvider: CalendarSyncProvider {
    let descriptor: ProviderDescriptor
    private let account: ConnectedAccount
    private let tokenManager: OAuthTokenManager
    private let session: URLSession

    init(account: ConnectedAccount, tokenManager: OAuthTokenManager, session: URLSession = .shared) {
        self.account = account
        self.tokenManager = tokenManager
        self.session = session
        self.descriptor = ProviderDescriptor(
            id: .googleCalendar,
            authMode: .oauthPKCE,
            capabilities: [.readEvents, .recurringEvents, .cancellationHandling],
            notes: "Google Calendar API v3"
        )
    }

    func discoverAccounts() async throws -> [ConnectedAccount] { [account] }

    func discoverSources(for account: ConnectedAccount) async throws -> [CalendarSource] {
        let token = try await tokenManager.accessToken()
        let url = URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!
        let data = try await get(url, token: token)
        return GoogleCalendarMapper.sources(from: data, account: account)
    }

    func initialSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult { try await sync(request) }
    func incrementalSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult { try await sync(request) }

    private func sync(_ request: ProviderSyncRequest) async throws -> ProviderSyncResult {
        let token = try await tokenManager.accessToken()
        let sources = request.sources.isEmpty ? try await discoverSources(for: request.account) : request.sources
        let formatter = ISO8601DateFormatter()

        var occurrences: [AlertOccurrence] = []
        for source in sources {
            let calendarID = source.externalID.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? source.externalID
            var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarID)/events")!
            components.queryItems = [
                URLQueryItem(name: "timeMin", value: formatter.string(from: request.windowStart)),
                URLQueryItem(name: "timeMax", value: formatter.string(from: request.windowEnd)),
                URLQueryItem(name: "singleEvents", value: "true"),
                URLQueryItem(name: "orderBy", value: "startTime"),
                URLQueryItem(name: "maxResults", value: "100")
            ]
            let data = try await get(components.url!, token: token)
            occurrences.append(contentsOf: try GoogleCalendarMapper.occurrences(from: data, account: request.account, source: source))
        }

        let cursor = SyncCursor(
            providerID: .googleCalendar,
            accountID: request.account.id,
            sourceID: request.sources.first?.id ?? "all",
            value: "synced-\(Int(request.windowEnd.timeIntervalSince1970))",
            updatedAt: Date()
        )
        return ProviderSyncResult(occurrences: occurrences, nextCursor: cursor, completedAt: Date())
    }

    private func get(_ url: URL, token: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ProviderSyncError.transport(String(data: data, encoding: .utf8) ?? "Google request failed")
        }
        return data
    }
}

/// Pure decoding of Google Calendar API responses into the foundation's model.
enum GoogleCalendarMapper {
    private struct CalendarListResponse: Decodable { let items: [CalendarEntry]? }
    private struct CalendarEntry: Decodable {
        let id: String
        let summary: String?
        let backgroundColor: String?
    }

    private struct EventsResponse: Decodable { let items: [Event]? }
    private struct Event: Decodable {
        let id: String?
        let summary: String?
        let status: String?
        let location: String?
        let hangoutLink: String?
        let organizer: Organizer?
        let start: EventDateTime?
        let end: EventDateTime?

        struct Organizer: Decodable { let displayName: String?; let email: String? }
        struct EventDateTime: Decodable { let dateTime: String?; let date: String? }
    }

    static func sources(from data: Data, account: ConnectedAccount) -> [CalendarSource] {
        guard let response = try? JSONDecoder().decode(CalendarListResponse.self, from: data) else { return [] }
        return (response.items ?? []).map { entry in
            CalendarSource(
                id: entry.id,
                title: entry.summary ?? entry.id,
                sourceTitle: "Google Calendar",
                providerID: .googleCalendar,
                accountID: account.id,
                externalID: entry.id
            )
        }
    }

    static func occurrences(from data: Data, account: ConnectedAccount, source: CalendarSource, colorHex: String? = nil) throws -> [AlertOccurrence] {
        let response = try JSONDecoder().decode(EventsResponse.self, from: data)
        return (response.items ?? []).compactMap { occurrence(from: $0, account: account, source: source, colorHex: colorHex) }
    }

    private static func occurrence(from event: Event, account: ConnectedAccount, source: CalendarSource, colorHex: String?) -> AlertOccurrence? {
        guard let startRaw = event.start?.dateTime ?? event.start?.date, let start = parseDate(startRaw) else { return nil }
        let isAllDay = event.start?.dateTime == nil
        let end = (event.end?.dateTime ?? event.end?.date).flatMap(parseDate) ?? start.addingTimeInterval(1800)
        let status: AlertOccurrenceStatus = event.status == "cancelled" ? .cancelled : .confirmed
        let externalID = event.id ?? "\(startRaw)-\(event.summary ?? "")"
        let title = (event.summary?.isEmpty == false) ? event.summary! : "Untitled event"

        return AlertOccurrence(
            id: "google_calendar:\(account.id):\(source.id):\(externalID)",
            title: title,
            startDate: start,
            endDate: end,
            calendarTitle: source.title,
            location: event.location,
            providerID: .googleCalendar,
            accountID: account.id,
            sourceID: source.id,
            externalID: externalID,
            status: status,
            isAllDay: isAllDay,
            organizer: event.organizer?.displayName ?? event.organizer?.email,
            calendarColorHex: colorHex,
            meetingURL: event.hangoutLink.flatMap { URL(string: $0) }
        )
    }

    static func parseDate(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }
}
