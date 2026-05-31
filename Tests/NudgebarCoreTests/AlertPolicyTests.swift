import NudgebarCore
import XCTest

final class AlertPolicyTests: XCTestCase {
    func testReturnsEventsInsideLeadTimeWindow() {
        let now = Date(timeIntervalSince1970: 1_000)
        let dueEvent = event(id: "due", startDate: now.addingTimeInterval(60))
        let futureEvent = event(id: "future", startDate: now.addingTimeInterval(10 * 60))
        let pastEvent = event(id: "past", startDate: now.addingTimeInterval(-60))

        let alerts = AlertPolicy.eventsToAlert(
            events: [futureEvent, dueEvent, pastEvent],
            now: now,
            leadTime: 5 * 60,
            alertedIDs: []
        )

        XCTAssertEqual(alerts.map(\.id), ["due"])
    }

    func testSkipsAlreadyAlertedEvents() {
        let now = Date(timeIntervalSince1970: 1_000)
        let dueEvent = event(id: "due", startDate: now.addingTimeInterval(60))

        let alerts = AlertPolicy.eventsToAlert(
            events: [dueEvent],
            now: now,
            leadTime: 5 * 60,
            alertedIDs: ["due"]
        )

        XCTAssertTrue(alerts.isEmpty)
    }

    func testFiltersAllDayAndCancelledEvents() {
        let now = Date(timeIntervalSince1970: 1_000)
        let allDay = event(id: "all-day", startDate: now.addingTimeInterval(60), isAllDay: true)
        let cancelled = event(id: "cancelled", startDate: now.addingTimeInterval(60), status: .cancelled)

        let alerts = AlertPolicy.eventsToAlert(
            events: [allDay, cancelled],
            now: now,
            leadTime: 5 * 60,
            alertedIDs: []
        )

        XCTAssertTrue(alerts.isEmpty)
    }

    private func event(
        id: String,
        startDate: Date,
        isAllDay: Bool = false,
        status: AlertOccurrenceStatus = .confirmed
    ) -> AlertCandidate {
        AlertCandidate(
            id: id,
            title: id,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(30 * 60),
            calendarTitle: "Work",
            status: status,
            isAllDay: isAllDay
        )
    }
}
