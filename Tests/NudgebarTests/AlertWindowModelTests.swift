import XCTest
import NudgebarCore
@testable import Nudgebar

@MainActor
final class AlertWindowModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_768_471_200)
    private let never = AlertPreferences.autoDismissNeverSentinel

    private func event(_ id: String) -> AlertCandidate {
        AlertOccurrence(
            id: id,
            title: id,
            startDate: now.addingTimeInterval(300),
            endDate: now.addingTimeInterval(1800),
            calendarTitle: "Work"
        )
    }

    func testAddAppendsAndDedupesByID() {
        let model = AlertWindowModel()
        model.add(event: event("a"), autoDismissSeconds: never, now: now)
        model.add(event: event("a"), autoDismissSeconds: never, now: now)
        model.add(event: event("b"), autoDismissSeconds: never, now: now)
        XCTAssertEqual(model.cards.map(\.id), ["a", "b"])
    }

    func testDismissOneKeepsWindowOpen() {
        var emptied = 0
        let model = AlertWindowModel()
        model.onEmptied = { emptied += 1 }
        model.add(event: event("a"), autoDismissSeconds: never, now: now)
        model.add(event: event("b"), autoDismissSeconds: never, now: now)
        model.dismiss(id: "a")
        XCTAssertEqual(model.cards.map(\.id), ["b"])
        XCTAssertEqual(emptied, 0)
    }

    func testDismissLastEmptiesWindow() {
        var emptied = 0
        let model = AlertWindowModel()
        model.onEmptied = { emptied += 1 }
        model.add(event: event("a"), autoDismissSeconds: never, now: now)
        model.dismiss(id: "a")
        XCTAssertTrue(model.cards.isEmpty)
        XCTAssertEqual(emptied, 1)
    }

    func testDismissAllClosesWindow() {
        var emptied = 0
        let model = AlertWindowModel()
        model.onEmptied = { emptied += 1 }
        ["a", "b", "c"].forEach { model.add(event: event($0), autoDismissSeconds: never, now: now) }
        model.dismissAll()
        XCTAssertTrue(model.cards.isEmpty)
        XCTAssertEqual(emptied, 1)
    }

    func testSnoozeAllSnoozesEveryCardAndCloses() {
        var snoozed: [String] = []
        var emptied = 0
        let model = AlertWindowModel()
        model.onSnooze = { event, _ in snoozed.append(event.id) }
        model.onEmptied = { emptied += 1 }
        ["a", "b"].forEach { model.add(event: event($0), autoDismissSeconds: never, now: now) }
        model.snoozeAll(minutes: 5)
        XCTAssertEqual(Set(snoozed), ["a", "b"])
        XCTAssertTrue(model.cards.isEmpty)
        XCTAssertEqual(emptied, 1)
    }

    func testSnoozeOneCardInvokesCallbackAndRemoves() {
        var snoozed: [(String, Int)] = []
        let model = AlertWindowModel()
        model.onSnooze = { event, minutes in snoozed.append((event.id, minutes)) }
        model.add(event: event("a"), autoDismissSeconds: never, now: now)
        model.snooze(id: "a", minutes: 10)
        XCTAssertEqual(snoozed.map(\.0), ["a"])
        XCTAssertEqual(snoozed.first?.1, 10)
        XCTAssertTrue(model.cards.isEmpty)
    }
}
