import XCTest
@testable import AlertBar

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

    func testSortsEventsByStartDate() {
        let now = Date(timeIntervalSince1970: 1_000)
        let first = event(id: "first", startDate: now.addingTimeInterval(60))
        let second = event(id: "second", startDate: now.addingTimeInterval(120))

        let alerts = AlertPolicy.eventsToAlert(
            events: [second, first],
            now: now,
            leadTime: 5 * 60,
            alertedIDs: []
        )

        XCTAssertEqual(alerts.map(\.id), ["first", "second"])
    }

    private func event(id: String, startDate: Date) -> AlertCandidate {
        AlertCandidate(
            id: id,
            title: id,
            startDate: startDate,
            endDate: startDate.addingTimeInterval(30 * 60),
            calendarTitle: "Work"
        )
    }
}
