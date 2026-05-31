import NudgebarAuth
import NudgebarCore
import NudgebarProviders
import Foundation

/// Real Microsoft Graph calendar client. Requests times in UTC via the Prefer
/// header; decoding lives in the pure, unit-tested `MicrosoftGraphMapper`.
final class MicrosoftGraphProvider: CalendarSyncProvider {
    let descriptor: ProviderDescriptor
    private let account: ConnectedAccount
    private let tokenManager: OAuthTokenManager
    private let session: URLSession

    init(account: ConnectedAccount, tokenManager: OAuthTokenManager, session: URLSession = .shared) {
        self.account = account
        self.tokenManager = tokenManager
        self.session = session
        self.descriptor = ProviderDescriptor(
            id: .microsoftGraph,
            authMode: .oauthPKCE,
            capabilities: [.readEvents, .recurringEvents, .cancellationHandling],
            notes: "Microsoft Graph"
        )
    }

    func discoverAccounts() async throws -> [ConnectedAccount] { [account] }

    func discoverSources(for account: ConnectedAccount) async throws -> [CalendarSource] {
        let token = try await tokenManager.accessToken()
        let data = try await get(URL(string: "https://graph.microsoft.com/v1.0/me/calendars")!, token: token)
        return MicrosoftGraphMapper.sources(from: data, account: account)
    }

    func initialSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult { try await sync(request) }
    func incrementalSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult { try await sync(request) }

    private func sync(_ request: ProviderSyncRequest) async throws -> ProviderSyncResult {
        let token = try await tokenManager.accessToken()
        let sources = request.sources.isEmpty ? try await discoverSources(for: request.account) : request.sources
        let formatter = ISO8601DateFormatter()

        var occurrences: [AlertOccurrence] = []
        for source in sources {
            var components = URLComponents(string: "https://graph.microsoft.com/v1.0/me/calendars/\(source.externalID)/calendarView")!
            components.queryItems = [
                URLQueryItem(name: "startDateTime", value: formatter.string(from: request.windowStart)),
                URLQueryItem(name: "endDateTime", value: formatter.string(from: request.windowEnd)),
                URLQueryItem(name: "$top", value: "100"),
                URLQueryItem(name: "$orderby", value: "start/dateTime")
            ]
            let data = try await get(components.url!, token: token, preferUTC: true)
            occurrences.append(contentsOf: try MicrosoftGraphMapper.occurrences(from: data, account: request.account, source: source))
        }

        let cursor = SyncCursor(providerID: .microsoftGraph, accountID: request.account.id, sourceID: request.sources.first?.id ?? "all", value: "synced", updatedAt: Date())
        return ProviderSyncResult(occurrences: occurrences, nextCursor: cursor, completedAt: Date())
    }

    private func get(_ url: URL, token: String, preferUTC: Bool = false) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if preferUTC { request.setValue("outlook.timezone=\"UTC\"", forHTTPHeaderField: "Prefer") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ProviderSyncError.transport(String(data: data, encoding: .utf8) ?? "Microsoft Graph request failed")
        }
        return data
    }
}

enum MicrosoftGraphMapper {
    private struct CalendarList: Decodable { let value: [GraphCalendar]? }
    private struct GraphCalendar: Decodable { let id: String; let name: String? }

    private struct EventList: Decodable { let value: [Event]? }
    private struct Event: Decodable {
        let id: String?
        let subject: String?
        let isCancelled: Bool?
        let isAllDay: Bool?
        let location: Location?
        let organizer: Organizer?
        let onlineMeeting: OnlineMeeting?
        let start: GraphDateTime?
        let end: GraphDateTime?

        struct Location: Decodable { let displayName: String? }
        struct Organizer: Decodable { let emailAddress: EmailAddress? }
        struct EmailAddress: Decodable { let name: String?; let address: String? }
        struct OnlineMeeting: Decodable { let joinUrl: String? }
        struct GraphDateTime: Decodable { let dateTime: String?; let timeZone: String? }
    }

    static func sources(from data: Data, account: ConnectedAccount) -> [CalendarSource] {
        guard let list = try? JSONDecoder().decode(CalendarList.self, from: data) else { return [] }
        return (list.value ?? []).map { calendar in
            CalendarSource(
                id: calendar.id,
                title: calendar.name ?? "Calendar",
                sourceTitle: "Microsoft 365",
                providerID: .microsoftGraph,
                accountID: account.id,
                externalID: calendar.id
            )
        }
    }

    static func occurrences(from data: Data, account: ConnectedAccount, source: CalendarSource) throws -> [AlertOccurrence] {
        let list = try JSONDecoder().decode(EventList.self, from: data)
        return (list.value ?? []).compactMap { occurrence(from: $0, account: account, source: source) }
    }

    private static func occurrence(from event: Event, account: ConnectedAccount, source: CalendarSource) -> AlertOccurrence? {
        guard let startRaw = event.start?.dateTime, let start = parseDate(startRaw) else { return nil }
        let end = event.end?.dateTime.flatMap(parseDate) ?? start.addingTimeInterval(1800)
        let externalID = event.id ?? "\(startRaw)-\(event.subject ?? "")"
        let status: AlertOccurrenceStatus = (event.isCancelled == true) ? .cancelled : .confirmed
        let title = (event.subject?.isEmpty == false) ? event.subject! : "Untitled event"
        return AlertOccurrence(
            id: "microsoft_graph:\(account.id):\(source.id):\(externalID)",
            title: title,
            startDate: start,
            endDate: end,
            calendarTitle: source.title,
            location: event.location?.displayName,
            providerID: .microsoftGraph,
            accountID: account.id,
            sourceID: source.id,
            externalID: externalID,
            status: status,
            isAllDay: event.isAllDay ?? false,
            organizer: event.organizer?.emailAddress?.name ?? event.organizer?.emailAddress?.address,
            meetingURL: event.onlineMeeting?.joinUrl.flatMap { URL(string: $0) }
        )
    }

    /// Graph returns local-naive datetimes (e.g. "2026-01-15T10:00:00.0000000")
    /// alongside a timeZone; we request UTC via the Prefer header and parse as UTC.
    static func parseDate(_ raw: String) -> Date? {
        let trimmed = String(raw.split(separator: ".").first ?? Substring(raw))
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: trimmed)
    }
}
