import NudgebarCore
import NudgebarPersistence
import XCTest

final class PersistenceTests: XCTestCase {
    func testSettingsPersistInUserDefaults() throws {
        let suiteName = "NudgebarPersistenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsSettingsStore(defaults: defaults)
        let settings = AlertSettings(
            leadMinutes: 15,
            fullScreenAlerts: false,
            enabledProviderIDs: [.eventKit, .googleCalendar],
            selectedSourceIDs: ["work"]
        )

        try store.saveSettings(settings)

        XCTAssertEqual(try store.loadSettings(), settings)
    }

    func testJSONStorePersistsMetadataCursorsAlertStateAndCache() throws {
        let now = Date(timeIntervalSince1970: 4_000)
        let store = JSONFilePersistenceStore(directory: temporaryDirectory())
        let account = ConnectedAccount(
            id: "google-account",
            providerID: .googleCalendar,
            displayName: "Google",
            username: "person@example.com",
            credentialReference: CredentialReference(service: "Nudgebar.Google", account: "google-account", kind: "oauthRefreshToken")
        )
        let source = CalendarSource(
            id: "work",
            title: "Work",
            sourceTitle: "Google",
            providerID: .googleCalendar,
            accountID: account.id
        )
        let cursor = SyncCursor(
            providerID: .googleCalendar,
            accountID: account.id,
            sourceID: source.id,
            value: "cursor-1",
            updatedAt: now
        )
        let occurrence = AlertOccurrence(
            id: "event",
            title: "Planning",
            startDate: now.addingTimeInterval(60),
            endDate: now.addingTimeInterval(30 * 60),
            calendarTitle: "Work",
            providerID: .googleCalendar,
            accountID: account.id,
            sourceID: source.id
        )
        let group = AlertOccurrenceGrouper.groups(for: [occurrence])[0]
        let state = AlertStateReducer.markPresented(group: group, now: now)

        try store.saveAccounts([account])
        try store.saveSources([source])
        try store.saveSyncCursors([cursor])
        try store.saveAlertStates([group.id: state])
        try store.saveCachedOccurrences([occurrence], validUntil: now.addingTimeInterval(60 * 60))

        XCTAssertEqual(try store.loadAccounts(), [account])
        XCTAssertEqual(try store.loadSources(), [source])
        XCTAssertEqual(try store.loadSyncCursors(), [cursor])
        XCTAssertEqual(try store.loadAlertStates(), [group.id: state])
        XCTAssertEqual(try store.loadCachedOccurrences(now: now), [occurrence])
    }

    func testExpiredEventCacheIsDisposable() throws {
        let now = Date(timeIntervalSince1970: 4_000)
        let store = JSONFilePersistenceStore(directory: temporaryDirectory())
        let occurrence = AlertOccurrence(
            id: "event",
            title: "Planning",
            startDate: now,
            endDate: now.addingTimeInterval(30 * 60),
            calendarTitle: "Work"
        )

        try store.saveCachedOccurrences([occurrence], validUntil: now.addingTimeInterval(-1))

        XCTAssertTrue(try store.loadCachedOccurrences(now: now).isEmpty)
    }

    func testSensitiveValuesAreRejectedOutsideKeychain() throws {
        XCTAssertThrowsError(
            try SensitiveDataGuard.validateNonSensitive(
                key: "refresh_token",
                valueDescription: "not shown"
            )
        )
        XCTAssertThrowsError(
            try SensitiveDataGuard.validateNonSensitive(
                key: "settings",
                valueDescription: "Bearer should-not-be-here"
            )
        )
    }

    func testAccountMetadataPersistsCredentialReferenceButNotSecretMaterial() throws {
        let directory = temporaryDirectory()
        let store = JSONFilePersistenceStore(directory: directory)
        let account = ConnectedAccount(
            id: "acuity",
            providerID: .acuity,
            displayName: "Acuity",
            credentialReference: CredentialReference(
                service: "Nudgebar.Acuity",
                account: "acuity",
                kind: "apiKey"
            )
        )

        try store.saveAccounts([account])

        let data = try Data(contentsOf: directory.appendingPathComponent("accounts.json"))
        let json = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(json.contains("Nudgebar.Acuity"))
        XCTAssertFalse(json.contains("super-secret"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("Bearer "))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("NudgebarPersistenceTests-\(UUID().uuidString)", isDirectory: true)
    }

}
