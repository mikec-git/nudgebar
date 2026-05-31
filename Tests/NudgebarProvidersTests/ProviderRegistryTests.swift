import NudgebarCore
import NudgebarProviders
import XCTest

final class ProviderRegistryTests: XCTestCase {
    func testRegistryListsMVPProviders() {
        XCTAssertEqual(
            ProviderRegistry.providerOrder,
            [.eventKit, .googleCalendar, .microsoftGraph, .calDAV, .calendly, .calCom, .acuity]
        )
    }

    func testDescriptorsExposeSyncCapabilities() {
        for providerID in ProviderRegistry.providerOrder {
            let descriptor = ProviderRegistry.descriptor(for: providerID)
            XCTAssertTrue(descriptor.capabilities.contains(.sourceDiscovery))
            XCTAssertTrue(
                descriptor.capabilities.contains(.deltaSync)
                    || descriptor.capabilities.contains(.pollingSync)
                    || descriptor.capabilities.contains(.localChangeNotifications)
            )
        }
    }

    func testFixtureProvidersSyncOfflineAndNormalizeOccurrences() async throws {
        let now = Date(timeIntervalSince1970: 3_000)
        let providers = OfflineProviderConnectorFactory.makeConnectors(now: now)

        for provider in providers {
            let account = (try await provider.discoverAccounts()).first!
            let sources = try await provider.discoverSources(for: account)
            let result = try await provider.initialSync(
                request: ProviderSyncRequest(
                    account: account,
                    sources: sources,
                    windowStart: now,
                    windowEnd: now.addingTimeInterval(60 * 60),
                    trigger: .initial
                )
            )

            XCTAssertEqual(result.occurrences.count, 1)
            XCTAssertEqual(result.occurrences[0].providerID, provider.descriptor.id)
            XCTAssertNotNil(result.nextCursor)
        }
    }

    func testProviderSpecificCursorMetadataIsRecorded() async throws {
        let now = Date(timeIntervalSince1970: 3_000)
        let providers = OfflineProviderConnectorFactory.makeConnectors(now: now)
        var metadataByProvider: [ProviderID: [String: String]] = [:]

        for provider in providers {
            let account = (try await provider.discoverAccounts()).first!
            let sources = try await provider.discoverSources(for: account)
            let result = try await provider.incrementalSync(
                request: ProviderSyncRequest(
                    account: account,
                    sources: sources,
                    windowStart: now,
                    windowEnd: now.addingTimeInterval(60 * 60),
                    trigger: .incremental
                )
            )
            metadataByProvider[provider.descriptor.id] = result.nextCursor?.metadata ?? [:]
        }

        XCTAssertEqual(metadataByProvider[.googleCalendar]?["syncToken"], "fixture-google-token")
        XCTAssertEqual(metadataByProvider[.microsoftGraph]?["deltaLink"], "fixture-microsoft-delta")
        XCTAssertEqual(metadataByProvider[.calDAV]?["etag"], "fixture-etag")
    }

    func testCalDAVConnectorRequiresHTTPSDiscovery() {
        let account = ConnectedAccount(id: "caldav", providerID: .calDAV, displayName: "CalDAV")

        XCTAssertThrowsError(
            try CalDAVCalendarConnector(
                account: account,
                accountDiscoveryURL: URL(string: "http://caldav.example.test")!,
                fixtures: []
            )
        )
    }

    func testGoogleExpiredSyncTokenFallsBackToFullSync() async throws {
        let now = Date(timeIntervalSince1970: 3_000)
        let account = ConnectedAccount(id: "google", providerID: .googleCalendar, displayName: "Google")
        let connector = GoogleCalendarConnector(
            account: account,
            fixtures: [
                ProviderEventFixture(
                    externalID: "event",
                    title: "Planning",
                    startDate: now.addingTimeInterval(60),
                    endDate: now.addingTimeInterval(30 * 60),
                    sourceID: "work",
                    sourceTitle: "Work",
                    updatedAt: now
                )
            ]
        )
        let sources = try await connector.discoverSources(for: account)
        let result = try await connector.incrementalSync(
            request: ProviderSyncRequest(
                account: account,
                sources: sources,
                windowStart: now,
                windowEnd: now.addingTimeInterval(60 * 60),
                previousCursor: SyncCursor(
                    providerID: .googleCalendar,
                    accountID: account.id,
                    sourceID: "work",
                    value: "expired",
                    updatedAt: now,
                    metadata: ["syncToken": "expired"]
                ),
                trigger: .incremental
            )
        )

        XCTAssertEqual(result.occurrences.count, 1)
        XCTAssertEqual(result.nextCursor?.metadata["syncToken"], "fixture-google-token")
    }
}
