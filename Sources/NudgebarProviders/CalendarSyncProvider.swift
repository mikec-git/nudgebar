import NudgebarAuth
import NudgebarCore
import Foundation

public protocol CalendarSyncProvider {
    var descriptor: ProviderDescriptor { get }

    func discoverAccounts() async throws -> [ConnectedAccount]
    func discoverSources(for account: ConnectedAccount) async throws -> [CalendarSource]
    func initialSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult
    func incrementalSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult
}

public struct ProviderEventFixture: Codable, Equatable, Sendable {
    public let externalID: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let sourceID: String
    public let sourceTitle: String
    public let location: String?
    public let timeZoneIdentifier: String?
    public let status: AlertOccurrenceStatus
    public let isAllDay: Bool
    public let updatedAt: Date

    public init(
        externalID: String,
        title: String,
        startDate: Date,
        endDate: Date,
        sourceID: String,
        sourceTitle: String,
        location: String? = nil,
        timeZoneIdentifier: String? = TimeZone.current.identifier,
        status: AlertOccurrenceStatus = .confirmed,
        isAllDay: Bool = false,
        updatedAt: Date
    ) {
        self.externalID = externalID
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.sourceID = sourceID
        self.sourceTitle = sourceTitle
        self.location = location
        self.timeZoneIdentifier = timeZoneIdentifier
        self.status = status
        self.isAllDay = isAllDay
        self.updatedAt = updatedAt
    }
}

public final class FixtureCalendarProvider: CalendarSyncProvider {
    public let descriptor: ProviderDescriptor
    private let account: ConnectedAccount
    private let fixtures: [ProviderEventFixture]
    private let deletedExternalIDs: Set<String>

    public init(
        descriptor: ProviderDescriptor,
        account: ConnectedAccount,
        fixtures: [ProviderEventFixture],
        deletedExternalIDs: Set<String> = []
    ) {
        self.descriptor = descriptor
        self.account = account
        self.fixtures = fixtures
        self.deletedExternalIDs = deletedExternalIDs
    }

    public func discoverAccounts() async throws -> [ConnectedAccount] {
        [account]
    }

    public func discoverSources(for account: ConnectedAccount) async throws -> [CalendarSource] {
        guard account.providerID == descriptor.id else {
            throw ProviderSyncError.sourceUnavailable(account.id)
        }

        let sources = Dictionary(grouping: fixtures, by: \.sourceID)
        return sources.map { sourceID, sourceFixtures in
            CalendarSource(
                id: sourceID,
                title: sourceFixtures[0].sourceTitle,
                sourceTitle: descriptor.displayName,
                providerID: descriptor.id,
                accountID: account.id,
                externalID: sourceID
            )
        }
        .sorted { $0.title < $1.title }
    }

    public func initialSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult {
        try makeResult(request: request)
    }

    public func incrementalSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult {
        try makeResult(request: request)
    }

    private func makeResult(request: ProviderSyncRequest) throws -> ProviderSyncResult {
        guard request.account.providerID == descriptor.id else {
            throw ProviderSyncError.credentialsUnavailable(descriptor.id)
        }

        let selectedSourceIDs = Set(request.sources.map(\.id))
        let occurrences = fixtures
            .filter { fixture in
                selectedSourceIDs.isEmpty || selectedSourceIDs.contains(fixture.sourceID)
            }
            .filter { fixture in
                fixture.endDate >= request.windowStart && fixture.startDate <= request.windowEnd
            }
            .map { normalize($0, account: request.account) }

        let cursor = SyncCursor(
            providerID: descriptor.id,
            accountID: request.account.id,
            sourceID: request.sources.first?.id ?? "all",
            value: "fixture-\(Int64(Date().timeIntervalSince1970))",
            updatedAt: Date(),
            metadata: cursorMetadata(for: descriptor.id)
        )

        return ProviderSyncResult(
            occurrences: occurrences,
            deletedOccurrenceIDs: deletedExternalIDs,
            nextCursor: cursor,
            completedAt: cursor.updatedAt
        )
    }

    private func normalize(
        _ fixture: ProviderEventFixture,
        account: ConnectedAccount
    ) -> AlertOccurrence {
        AlertOccurrence(
            id: "\(descriptor.id.rawValue):\(account.id):\(fixture.sourceID):\(fixture.externalID)",
            title: fixture.title,
            startDate: fixture.startDate,
            endDate: fixture.endDate,
            calendarTitle: fixture.sourceTitle,
            location: fixture.location,
            providerID: descriptor.id,
            accountID: account.id,
            sourceID: fixture.sourceID,
            externalID: fixture.externalID,
            timeZoneIdentifier: fixture.timeZoneIdentifier,
            status: fixture.status,
            isAllDay: fixture.isAllDay,
            lastModified: fixture.updatedAt
        )
    }

    private func cursorMetadata(for providerID: ProviderID) -> [String: String] {
        switch providerID {
        case .googleCalendar:
            return ["syncToken": "fixture-google-token"]
        case .microsoftGraph:
            return ["deltaLink": "fixture-microsoft-delta"]
        case .calDAV:
            return ["syncToken": "fixture-caldav-sync", "etag": "fixture-etag"]
        case .eventKit:
            return ["lastRefresh": "fixture-eventkit-refresh"]
        case .calendly, .calCom, .acuity:
            return ["pollCursor": "fixture-poll-cursor"]
        }
    }
}
