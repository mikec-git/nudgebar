import NudgebarCore
import NudgebarProviders
import Foundation

// MARK: - Cal.com

/// Real Cal.com client (API key). Decoding lives in the pure CalComMapper.
final class CalComProvider: CalendarSyncProvider {
    let descriptor: ProviderDescriptor
    private let account: ConnectedAccount
    private let apiKey: String
    private let session: URLSession

    init(account: ConnectedAccount, apiKey: String, session: URLSession = .shared) {
        self.account = account
        self.apiKey = apiKey
        self.session = session
        self.descriptor = ProviderDescriptor(id: .calCom, authMode: .apiKey, capabilities: [.readEvents, .schedulingBookings, .pollingSync], notes: "Cal.com bookings")
    }

    func discoverAccounts() async throws -> [ConnectedAccount] { [account] }

    func discoverSources(for account: ConnectedAccount) async throws -> [CalendarSource] {
        [CalendarSource(id: account.id, title: "Cal.com", sourceTitle: "Cal.com", providerID: .calCom, accountID: account.id, externalID: account.id)]
    }

    func initialSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult { try await sync(request) }
    func incrementalSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult { try await sync(request) }

    private func sync(_ request: ProviderSyncRequest) async throws -> ProviderSyncResult {
        let sources = request.sources.isEmpty ? try await discoverSources(for: request.account) : request.sources
        guard let source = sources.first else {
            return ProviderSyncResult(occurrences: [], completedAt: Date())
        }
        let formatter = ISO8601DateFormatter()
        var components = URLComponents(string: "https://api.cal.com/v2/bookings")!
        components.queryItems = [
            URLQueryItem(name: "status", value: "upcoming"),
            URLQueryItem(name: "afterStart", value: formatter.string(from: request.windowStart))
        ]
        var urlRequest = URLRequest(url: components.url!)
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("2024-08-13", forHTTPHeaderField: "cal-api-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: urlRequest)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard 200..<300 ~= status else {
            throw ProviderSyncError.transport("HTTP \(status): " + (String(data: data, encoding: .utf8) ?? "Cal.com request failed"))
        }
        let occurrences = try CalComMapper.occurrences(from: data, account: request.account, source: source, windowStart: request.windowStart, windowEnd: request.windowEnd)
        let cursor = SyncCursor(providerID: .calCom, accountID: request.account.id, sourceID: source.id, value: "polled", updatedAt: Date())
        return ProviderSyncResult(occurrences: occurrences, nextCursor: cursor, completedAt: Date())
    }
}

enum CalComMapper {
    private struct Response: Decodable { let data: [Booking]? }
    private struct Booking: Decodable {
        let uid: String?
        let title: String?
        let start: String?
        let end: String?
        let status: String?
        let location: String?

        enum CodingKeys: String, CodingKey { case uid, title, start, end, status, location }
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            uid = try container.decodeIfPresent(String.self, forKey: .uid)
            title = try container.decodeIfPresent(String.self, forKey: .title)
            start = try container.decodeIfPresent(String.self, forKey: .start)
            end = try container.decodeIfPresent(String.self, forKey: .end)
            status = try container.decodeIfPresent(String.self, forKey: .status)
            // v2 location may be a plain string or a structured object; tolerate either.
            location = try? container.decodeIfPresent(String.self, forKey: .location)
        }
    }

    static func occurrences(from data: Data, account: ConnectedAccount, source: CalendarSource, windowStart: Date, windowEnd: Date) throws -> [AlertOccurrence] {
        let response = try JSONDecoder().decode(Response.self, from: data)
        return (response.data ?? []).compactMap { booking in
            occurrence(from: booking, account: account, source: source)
        }
        .filter { $0.startDate >= windowStart && $0.startDate <= windowEnd }
    }

    private static func occurrence(from booking: Booking, account: ConnectedAccount, source: CalendarSource) -> AlertOccurrence? {
        guard let startRaw = booking.start, let start = CalendarDateParsing.parse(startRaw) else { return nil }
        let end = booking.end.flatMap(CalendarDateParsing.parse) ?? start.addingTimeInterval(1800)
        let externalID = booking.uid ?? startRaw
        let status: AlertOccurrenceStatus = (booking.status == "cancelled" || booking.status == "rejected") ? .cancelled : .confirmed
        let meetingURL = booking.location.flatMap { URL(string: $0) }
        return AlertOccurrence(
            id: "cal_com:\(account.id):\(source.id):\(externalID)",
            title: (booking.title?.isEmpty == false) ? booking.title! : "Cal.com booking",
            startDate: start,
            endDate: end,
            calendarTitle: source.title,
            location: (meetingURL == nil) ? booking.location : nil,
            providerID: .calCom,
            accountID: account.id,
            sourceID: source.id,
            externalID: externalID,
            status: status,
            isAllDay: false,
            meetingURL: meetingURL
        )
    }
}

// MARK: - Acuity

/// Real Acuity Scheduling client (HTTP Basic with user ID + API key).
final class AcuityProvider: CalendarSyncProvider {
    let descriptor: ProviderDescriptor
    private let account: ConnectedAccount
    private let basicToken: String
    private let session: URLSession

    /// `credentials` is "userID:apiKey".
    init(account: ConnectedAccount, credentials: String, session: URLSession = .shared) {
        self.account = account
        self.basicToken = Data(credentials.utf8).base64EncodedString()
        self.session = session
        self.descriptor = ProviderDescriptor(id: .acuity, authMode: .basicAuth, capabilities: [.readEvents, .schedulingBookings, .pollingSync], notes: "Acuity appointments")
    }

    func discoverAccounts() async throws -> [ConnectedAccount] { [account] }

    func discoverSources(for account: ConnectedAccount) async throws -> [CalendarSource] {
        [CalendarSource(id: account.id, title: "Acuity", sourceTitle: "Acuity Scheduling", providerID: .acuity, accountID: account.id, externalID: account.id)]
    }

    func initialSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult { try await sync(request) }
    func incrementalSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult { try await sync(request) }

    private func sync(_ request: ProviderSyncRequest) async throws -> ProviderSyncResult {
        let sources = request.sources.isEmpty ? try await discoverSources(for: request.account) : request.sources
        guard let source = sources.first else {
            return ProviderSyncResult(occurrences: [], completedAt: Date())
        }
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"
        var components = URLComponents(string: "https://acuityscheduling.com/api/v1/appointments")!
        components.queryItems = [
            URLQueryItem(name: "minDate", value: dayFormatter.string(from: request.windowStart)),
            URLQueryItem(name: "maxDate", value: dayFormatter.string(from: request.windowEnd))
        ]
        var urlRequest = URLRequest(url: components.url!)
        urlRequest.setValue("Basic \(basicToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ProviderSyncError.transport(String(data: data, encoding: .utf8) ?? "Acuity request failed")
        }
        let occurrences = try AcuityMapper.occurrences(from: data, account: request.account, source: source, windowStart: request.windowStart, windowEnd: request.windowEnd)
        let cursor = SyncCursor(providerID: .acuity, accountID: request.account.id, sourceID: source.id, value: "polled", updatedAt: Date())
        return ProviderSyncResult(occurrences: occurrences, nextCursor: cursor, completedAt: Date())
    }
}

enum AcuityMapper {
    private struct Appointment: Decodable {
        let id: Int?
        let firstName: String?
        let lastName: String?
        let type: String?
        let datetime: String?
        let duration: String?
        let location: String?
    }

    static func occurrences(from data: Data, account: ConnectedAccount, source: CalendarSource, windowStart: Date, windowEnd: Date) throws -> [AlertOccurrence] {
        let appointments = try JSONDecoder().decode([Appointment].self, from: data)
        return appointments.compactMap { occurrence(from: $0, account: account, source: source) }
            .filter { $0.startDate >= windowStart && $0.startDate <= windowEnd }
    }

    private static func occurrence(from appointment: Appointment, account: ConnectedAccount, source: CalendarSource) -> AlertOccurrence? {
        guard let startRaw = appointment.datetime, let start = CalendarDateParsing.parse(startRaw) else { return nil }
        let durationMinutes = Double(appointment.duration ?? "") ?? 30
        let end = start.addingTimeInterval(durationMinutes * 60)
        let externalID = appointment.id.map(String.init) ?? startRaw
        let client = [appointment.firstName, appointment.lastName].compactMap { $0 }.joined(separator: " ")
        let title = (appointment.type?.isEmpty == false) ? appointment.type! : "Appointment"
        return AlertOccurrence(
            id: "acuity:\(account.id):\(source.id):\(externalID)",
            title: client.isEmpty ? title : "\(title) · \(client)",
            startDate: start,
            endDate: end,
            calendarTitle: source.title,
            location: appointment.location,
            providerID: .acuity,
            accountID: account.id,
            sourceID: source.id,
            externalID: externalID,
            status: .confirmed,
            isAllDay: false
        )
    }
}
