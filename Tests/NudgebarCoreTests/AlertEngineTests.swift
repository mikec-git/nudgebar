import NudgebarCore
import XCTest

final class AlertEngineTests: XCTestCase {
    func testGroupsCrossProviderDuplicatesAndPrefersDirectProvider() {
        let now = Date(timeIntervalSince1970: 2_000)
        let eventKit = occurrence(
            id: "eventkit",
            providerID: .eventKit,
            startDate: now.addingTimeInterval(60)
        )
        let google = occurrence(
            id: "google",
            providerID: .googleCalendar,
            startDate: now.addingTimeInterval(60)
        )

        let groups = AlertOccurrenceGrouper.groups(for: [eventKit, google])

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].occurrences.map(\.id).sorted(), ["eventkit", "google"])
        XCTAssertEqual(groups[0].primaryOccurrence.providerID, .googleCalendar)
    }

    func testPlannerEmitsPresentationRequestForDueAlert() {
        let now = Date(timeIntervalSince1970: 2_000)
        let due = occurrence(id: "due", providerID: .googleCalendar, startDate: now.addingTimeInterval(60))

        let plan = AlertPlanner.plan(
            occurrences: [due],
            states: [:],
            preferences: AlertPreferencesSnapshot(leadTime: 5 * 60, fullScreenAlerts: true),
            now: now
        )

        XCTAssertEqual(plan.dueGroups.count, 1)
        XCTAssertEqual(plan.presentationRequests[0].displayData.title, "Planning")
        XCTAssertTrue(plan.presentationRequests[0].fullScreen)
    }

    func testDismissAndSnoozeSuppressUntilExpectedTime() {
        let now = Date(timeIntervalSince1970: 2_000)
        let due = occurrence(id: "due", providerID: .googleCalendar, startDate: now.addingTimeInterval(60))
        let group = AlertOccurrenceGrouper.groups(for: [due])[0]
        let presented = AlertStateReducer.markPresented(group: group, now: now)
        let dismissed = AlertStateReducer.dismiss(presented, now: now.addingTimeInterval(10))

        var dismissedPlan = AlertPlanner.plan(
            occurrences: [due],
            states: [group.id: dismissed],
            preferences: AlertPreferencesSnapshot(leadTime: 5 * 60, fullScreenAlerts: true),
            now: now.addingTimeInterval(20)
        )
        XCTAssertTrue(dismissedPlan.presentationRequests.isEmpty)

        let snoozed = AlertStateReducer.snooze(
            presented,
            until: now.addingTimeInterval(120),
            now: now.addingTimeInterval(10)
        )
        dismissedPlan = AlertPlanner.plan(
            occurrences: [due],
            states: [group.id: snoozed],
            preferences: AlertPreferencesSnapshot(leadTime: 5 * 60, fullScreenAlerts: true),
            now: now.addingTimeInterval(60)
        )
        XCTAssertTrue(dismissedPlan.presentationRequests.isEmpty)

        let resnoozedPlan = AlertPlanner.plan(
            occurrences: [due],
            states: [group.id: snoozed],
            preferences: AlertPreferencesSnapshot(leadTime: 5 * 60, fullScreenAlerts: true),
            now: now.addingTimeInterval(130)
        )
        XCTAssertEqual(resnoozedPlan.presentationRequests.count, 1)
    }

    func testLifecycleReconciliationRequestsProviderRefreshAndNextSchedule() {
        let now = Date(timeIntervalSince1970: 2_000)
        let future = occurrence(id: "future", providerID: .googleCalendar, startDate: now.addingTimeInterval(15 * 60))

        let result = AlertLifecycleReconciler.reconcile(
            reason: .wake,
            occurrences: [future],
            states: [:],
            preferences: AlertPreferencesSnapshot(leadTime: 5 * 60, fullScreenAlerts: true),
            now: now
        )

        XCTAssertTrue(result.needsProviderRefresh)
        XCTAssertEqual(result.nextSchedule?.groupID, result.plan.groups[0].id)
    }

    private func occurrence(
        id: String,
        providerID: ProviderID,
        startDate: Date
    ) -> AlertOccurrence {
        AlertOccurrence(
            id: id,
            title: "Planning",
            startDate: startDate,
            endDate: startDate.addingTimeInterval(30 * 60),
            calendarTitle: "Work",
            location: "Room 1",
            providerID: providerID,
            sourceID: "\(providerID.rawValue)-calendar"
        )
    }
}
