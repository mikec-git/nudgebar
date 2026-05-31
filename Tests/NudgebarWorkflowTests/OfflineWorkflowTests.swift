import NudgebarCore
import NudgebarPersistence
import NudgebarProviders
import XCTest

final class OfflineWorkflowTests: XCTestCase {
    func testConnectSyncPlanDismissSnoozeRestartAndResyncWorkflow() async throws {
        let now = Date(timeIntervalSince1970: 5_000)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NudgebarWorkflowTests-\(UUID().uuidString)", isDirectory: true)
        let store = JSONFilePersistenceStore(directory: directory)
        let provider = ProviderRegistry.makeFixtureProviders(
            now: now,
            fixtures: [
                .googleCalendar: [
                    ProviderEventFixture(
                        externalID: "planning",
                        title: "Planning",
                        startDate: now.addingTimeInterval(60),
                        endDate: now.addingTimeInterval(30 * 60),
                        sourceID: "work",
                        sourceTitle: "Work",
                        location: "Video",
                        updatedAt: now
                    )
                ]
            ]
        )
        .first { $0.descriptor.id == .googleCalendar }!

        let account = (try await provider.discoverAccounts()).first!
        let sources = try await provider.discoverSources(for: account)
        try store.saveAccounts([account])
        try store.saveSources(sources)

        let sync = try await provider.initialSync(
            request: ProviderSyncRequest(
                account: account,
                sources: sources,
                windowStart: now,
                windowEnd: now.addingTimeInterval(60 * 60),
                trigger: .initial
            )
        )
        try store.saveSyncCursors([sync.nextCursor].compactMap { $0 })
        try store.saveCachedOccurrences(sync.occurrences, validUntil: now.addingTimeInterval(60 * 60))

        let settings = AlertSettings(
            leadMinutes: 5,
            fullScreenAlerts: true,
            enabledProviderIDs: [.googleCalendar],
            selectedSourceIDs: Set(sources.map(\.id))
        )
        try store.saveSettings(settings)

        let plan = AlertPlanner.plan(
            occurrences: try store.loadCachedOccurrences(now: now),
            states: [:],
            preferences: settings.snapshot,
            now: now
        )
        XCTAssertEqual(plan.presentationRequests.count, 1)

        let group = try XCTUnwrap(plan.dueGroups.first)
        let presented = AlertStateReducer.markPresented(group: group, now: now)
        let dismissed = AlertStateReducer.dismiss(presented, now: now.addingTimeInterval(10))
        try store.saveAlertStates([group.id: dismissed])

        let restartedStore = JSONFilePersistenceStore(directory: directory)
        let restartedPlan = AlertPlanner.plan(
            occurrences: try restartedStore.loadCachedOccurrences(now: now.addingTimeInterval(20)),
            states: try restartedStore.loadAlertStates(),
            preferences: try restartedStore.loadSettings().snapshot,
            now: now.addingTimeInterval(20)
        )
        XCTAssertTrue(restartedPlan.presentationRequests.isEmpty)

        let snoozed = AlertStateReducer.snooze(
            presented,
            until: now.addingTimeInterval(120),
            now: now.addingTimeInterval(30)
        )
        try restartedStore.saveAlertStates([group.id: snoozed])

        let resync = try await provider.incrementalSync(
            request: ProviderSyncRequest(
                account: account,
                sources: sources,
                windowStart: now,
                windowEnd: now.addingTimeInterval(60 * 60),
                previousCursor: try restartedStore.loadSyncCursors().first,
                trigger: .incremental
            )
        )
        try restartedStore.saveCachedOccurrences(resync.occurrences, validUntil: now.addingTimeInterval(60 * 60))

        let snoozeDuePlan = AlertPlanner.plan(
            occurrences: try restartedStore.loadCachedOccurrences(now: now.addingTimeInterval(130)),
            states: try restartedStore.loadAlertStates(),
            preferences: try restartedStore.loadSettings().snapshot,
            now: now.addingTimeInterval(130)
        )

        XCTAssertEqual(snoozeDuePlan.presentationRequests.count, 1)
    }
}
