import NudgebarCore
import Foundation

public final class GoogleCalendarConnector: CalendarSyncProvider {
    public let descriptor = ProviderRegistry.descriptor(for: .googleCalendar)
    private let fixtureProvider: FixtureCalendarProvider

    public init(account: ConnectedAccount, fixtures: [ProviderEventFixture]) {
        self.fixtureProvider = FixtureCalendarProvider(
            descriptor: descriptor,
            account: account,
            fixtures: fixtures
        )
    }

    public func discoverAccounts() async throws -> [ConnectedAccount] {
        try await fixtureProvider.discoverAccounts()
    }

    public func discoverSources(for account: ConnectedAccount) async throws -> [CalendarSource] {
        try await fixtureProvider.discoverSources(for: account)
    }

    public func initialSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult {
        try await fixtureProvider.initialSync(request: request)
    }

    public func incrementalSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult {
        if request.previousCursor?.metadata["syncToken"] == "expired" {
            return try await initialSync(
                request: ProviderSyncRequest(
                    account: request.account,
                    sources: request.sources,
                    windowStart: request.windowStart,
                    windowEnd: request.windowEnd,
                    trigger: .initial
                )
            )
        }

        return try await fixtureProvider.incrementalSync(request: request)
    }
}

public final class MicrosoftGraphCalendarConnector: CalendarSyncProvider {
    public let descriptor = ProviderRegistry.descriptor(for: .microsoftGraph)
    private let fixtureProvider: FixtureCalendarProvider

    public init(account: ConnectedAccount, fixtures: [ProviderEventFixture]) {
        self.fixtureProvider = FixtureCalendarProvider(
            descriptor: descriptor,
            account: account,
            fixtures: fixtures
        )
    }

    public func discoverAccounts() async throws -> [ConnectedAccount] {
        try await fixtureProvider.discoverAccounts()
    }

    public func discoverSources(for account: ConnectedAccount) async throws -> [CalendarSource] {
        try await fixtureProvider.discoverSources(for: account)
    }

    public func initialSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult {
        try await fixtureProvider.initialSync(request: request)
    }

    public func incrementalSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult {
        try await fixtureProvider.incrementalSync(request: request)
    }
}

public final class CalDAVCalendarConnector: CalendarSyncProvider {
    public let descriptor = ProviderRegistry.descriptor(for: .calDAV)
    private let fixtureProvider: FixtureCalendarProvider
    public let accountDiscoveryURL: URL

    public init(
        account: ConnectedAccount,
        accountDiscoveryURL: URL,
        fixtures: [ProviderEventFixture]
    ) throws {
        guard accountDiscoveryURL.scheme?.lowercased() == "https" else {
            throw ProviderSyncError.unsupported("CalDAV account discovery requires HTTPS.")
        }

        self.accountDiscoveryURL = accountDiscoveryURL
        self.fixtureProvider = FixtureCalendarProvider(
            descriptor: descriptor,
            account: account,
            fixtures: fixtures
        )
    }

    public func discoverAccounts() async throws -> [ConnectedAccount] {
        try await fixtureProvider.discoverAccounts()
    }

    public func discoverSources(for account: ConnectedAccount) async throws -> [CalendarSource] {
        try await fixtureProvider.discoverSources(for: account)
    }

    public func initialSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult {
        try await fixtureProvider.initialSync(request: request)
    }

    public func incrementalSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult {
        try await fixtureProvider.incrementalSync(request: request)
    }
}

public final class SchedulingProviderConnector: CalendarSyncProvider {
    public let descriptor: ProviderDescriptor
    private let fixtureProvider: FixtureCalendarProvider

    public init(
        providerID: ProviderID,
        account: ConnectedAccount,
        fixtures: [ProviderEventFixture]
    ) {
        precondition([.calendly, .calCom, .acuity].contains(providerID))
        self.descriptor = ProviderRegistry.descriptor(for: providerID)
        self.fixtureProvider = FixtureCalendarProvider(
            descriptor: descriptor,
            account: account,
            fixtures: fixtures
        )
    }

    public func discoverAccounts() async throws -> [ConnectedAccount] {
        try await fixtureProvider.discoverAccounts()
    }

    public func discoverSources(for account: ConnectedAccount) async throws -> [CalendarSource] {
        try await fixtureProvider.discoverSources(for: account)
    }

    public func initialSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult {
        try await fixtureProvider.initialSync(request: request)
    }

    public func incrementalSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult {
        try await fixtureProvider.incrementalSync(request: request)
    }
}

public enum OfflineProviderConnectorFactory {
    public static func makeConnectors(
        now: Date,
        fixtures: [ProviderID: [ProviderEventFixture]] = [:]
    ) -> [any CalendarSyncProvider] {
        ProviderRegistry.providerOrder.compactMap { providerID in
            let account = ConnectedAccount(
                id: "\(providerID.rawValue)-account",
                providerID: providerID,
                displayName: providerID.displayName
            )
            let providerFixtures = fixtures[providerID] ?? [
                ProviderEventFixture(
                    externalID: "fixture-event",
                    title: "Fixture Event",
                    startDate: now.addingTimeInterval(10 * 60),
                    endDate: now.addingTimeInterval(40 * 60),
                    sourceID: "\(providerID.rawValue)-source",
                    sourceTitle: providerID.displayName,
                    updatedAt: now
                )
            ]

            switch providerID {
            case .eventKit:
                return FixtureCalendarProvider(
                    descriptor: ProviderRegistry.descriptor(for: providerID),
                    account: account,
                    fixtures: providerFixtures
                )
            case .googleCalendar:
                return GoogleCalendarConnector(account: account, fixtures: providerFixtures)
            case .microsoftGraph:
                return MicrosoftGraphCalendarConnector(account: account, fixtures: providerFixtures)
            case .calDAV:
                return try? CalDAVCalendarConnector(
                    account: account,
                    accountDiscoveryURL: URL(string: "https://caldav.example.test")!,
                    fixtures: providerFixtures
                )
            case .calendly, .calCom, .acuity:
                return SchedulingProviderConnector(
                    providerID: providerID,
                    account: account,
                    fixtures: providerFixtures
                )
            }
        }
    }
}
