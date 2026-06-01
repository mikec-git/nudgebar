import NudgebarAuth
import NudgebarCore
import NudgebarProviders
import Foundation

/// Real Calendly client (scheduled bookings). Decoding lives in the pure,
/// unit-tested `CalendlyMapper`.
final class CalendlyProvider: CalendarSyncProvider {
    let descriptor: ProviderDescriptor
    private let account: ConnectedAccount
    private let tokenManager: OAuthTokenManager
    private let session: URLSession

    init(account: ConnectedAccount, tokenManager: OAuthTokenManager, session: URLSession = .shared) {
        self.account = account
        self.tokenManager = tokenManager
        self.session = session
        self.descriptor = ProviderDescriptor(
            id: .calendly,
            authMode: .oauthPKCE,
            capabilities: [.readEvents, .schedulingBookings, .pollingSync],
            notes: "Calendly scheduled events"
        )
    }

    func discoverAccounts() async throws -> [ConnectedAccount] { [account] }

    func discoverSources(for account: ConnectedAccount) async throws -> [CalendarSource] {
        let token = try await tokenManager.accessToken()
        let data = try await get(URL(string: "https://api.calendly.com/users/me")!, token: token)
        guard let source = CalendlyMapper.source(from: data, account: account) else {
            throw ProviderSyncError.sourceUnavailable(account.id)
        }
        return [source]
    }

    func initialSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult { try await sync(request) }
    func incrementalSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult { try await sync(request) }

    private func sync(_ request: ProviderSyncRequest) async throws -> ProviderSyncResult {
        let token = try await tokenManager.accessToken()
        let sources = request.sources.isEmpty ? try await discoverSources(for: request.account) : request.sources
        guard let source = sources.first else {
            return ProviderSyncResult(occurrences: [], completedAt: Date())
        }
        let formatter = ISO8601DateFormatter()
        var components = URLComponents(string: "https://api.calendly.com/scheduled_events")!
        components.queryItems = [
            URLQueryItem(name: "user", value: source.externalID),
            URLQueryItem(name: "min_start_time", value: formatter.string(from: request.windowStart)),
            URLQueryItem(name: "max_start_time", value: formatter.string(from: request.windowEnd)),
            URLQueryItem(name: "status", value: "active"),
            URLQueryItem(name: "sort", value: "start_time:asc"),
            URLQueryItem(name: "count", value: "100")
        ]
        let data = try await get(components.url!, token: token)
        let occurrences = try CalendlyMapper.occurrences(from: data, account: request.account, source: source)
        let cursor = SyncCursor(providerID: .calendly, accountID: request.account.id, sourceID: source.id, value: "polled", updatedAt: Date())
        return ProviderSyncResult(occurrences: occurrences, nextCursor: cursor, completedAt: Date())
    }

    private func get(_ url: URL, token: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ProviderSyncError.transport(String(data: data, encoding: .utf8) ?? "Calendly request failed")
        }
        return data
    }
}

enum CalendlyMapper {
    private struct UserResponse: Decodable { let resource: Resource? }
    private struct Resource: Decodable { let uri: String?; let name: String? }

    private struct EventList: Decodable { let collection: [Event]? }
    private struct Event: Decodable {
        let uri: String?
        let name: String?
        let status: String?
        let start_time: String?
        let end_time: String?
        let location: Location?
        struct Location: Decodable { let type: String?; let location: String?; let join_url: String? }
    }

    static func source(from data: Data, account: ConnectedAccount) -> CalendarSource? {
        guard let response = try? JSONDecoder().decode(UserResponse.self, from: data), let uri = response.resource?.uri else {
            return nil
        }
        return CalendarSource(
            id: uri,
            title: response.resource?.name ?? "Calendly",
            sourceTitle: "Calendly",
            providerID: .calendly,
            accountID: account.id,
            externalID: uri
        )
    }

    static func occurrences(from data: Data, account: ConnectedAccount, source: CalendarSource) throws -> [AlertOccurrence] {
        let list = try JSONDecoder().decode(EventList.self, from: data)
        return (list.collection ?? []).compactMap { occurrence(from: $0, account: account, source: source) }
    }

    private static func occurrence(from event: Event, account: ConnectedAccount, source: CalendarSource) -> AlertOccurrence? {
        guard let startRaw = event.start_time, let start = CalendarDateParsing.parse(startRaw) else { return nil }
        let end = event.end_time.flatMap(CalendarDateParsing.parse) ?? start.addingTimeInterval(1800)
        let externalID = event.uri.map { String($0.split(separator: "/").last ?? "") } ?? startRaw
        let status: AlertOccurrenceStatus = event.status == "canceled" ? .cancelled : .confirmed
        let meetingURL = event.location?.join_url.flatMap { URL(string: $0) }
        return AlertOccurrence(
            id: "calendly:\(account.id):\(source.id):\(externalID)",
            title: (event.name?.isEmpty == false) ? event.name! : "Calendly booking",
            startDate: start,
            endDate: end,
            calendarTitle: source.title,
            location: event.location?.location,
            providerID: .calendly,
            accountID: account.id,
            sourceID: source.id,
            externalID: externalID,
            status: status,
            isAllDay: false,
            meetingURL: meetingURL
        )
    }
}
