import XCTest
import NudgebarCore
import NudgebarProviders
@testable import Nudgebar

@MainActor
final class ConnectorStoreTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_768_471_200)
    private let suite = "ConnectorStoreTests"

    private func freshDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private func fixtureProvider(for account: ConnectedAccount) -> CalendarSyncProvider {
        FixtureCalendarProvider(
            descriptor: ProviderDescriptor(id: .googleCalendar, authMode: .oauthPKCE, capabilities: [.readEvents], notes: ""),
            account: account,
            fixtures: [
                ProviderEventFixture(
                    externalID: "e1",
                    title: "Cloud sync",
                    startDate: now.addingTimeInterval(600),
                    endDate: now.addingTimeInterval(1200),
                    sourceID: "s1",
                    sourceTitle: "Work",
                    updatedAt: now
                )
            ]
        )
    }

    func testSyncMergesProviderOccurrences() async {
        let account = ConnectedAccount(id: "acc1", providerID: .googleCalendar, displayName: "Test")
        let store = ConnectorStore(defaults: freshDefaults()) { self.fixtureProvider(for: $0) }
        store.addAccount(account)

        await store.sync(windowStart: now, windowEnd: now.addingTimeInterval(3600))

        XCTAssertEqual(store.occurrences.count, 1)
        XCTAssertEqual(store.occurrences.first?.title, "Cloud sync")
        XCTAssertEqual(store.occurrences.first?.accountID, "acc1")
        XCTAssertNil(store.lastSyncError)
    }

    func testNoAccountsYieldsNoOccurrences() async {
        let store = ConnectorStore(defaults: freshDefaults()) { self.fixtureProvider(for: $0) }
        await store.sync(windowStart: now, windowEnd: now.addingTimeInterval(3600))
        XCTAssertTrue(store.occurrences.isEmpty)
    }

    func testRemoveAccountClearsOccurrences() async {
        let account = ConnectedAccount(id: "acc1", providerID: .googleCalendar, displayName: "Test")
        let store = ConnectorStore(defaults: freshDefaults()) { self.fixtureProvider(for: $0) }
        store.addAccount(account)
        await store.sync(windowStart: now, windowEnd: now.addingTimeInterval(3600))
        XCTAssertEqual(store.occurrences.count, 1)

        store.removeAccount(id: "acc1")
        XCTAssertTrue(store.occurrences.isEmpty)
        XCTAssertTrue(store.accounts.isEmpty)
    }
}
