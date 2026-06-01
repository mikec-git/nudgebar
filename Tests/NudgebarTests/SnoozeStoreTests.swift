import XCTest
@testable import Nudgebar

@MainActor
final class SnoozeStoreTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_768_471_200)

    func testSnoozeSetsUntilAndIsSnoozed() {
        let store = SnoozeStore()
        store.snooze(eventID: "e1", minutes: 5, now: now)
        XCTAssertEqual(store.snoozedUntil(eventID: "e1"), now.addingTimeInterval(300))
        XCTAssertTrue(store.isSnoozed(eventID: "e1", now: now))
        XCTAssertFalse(store.isSnoozed(eventID: "e1", now: now.addingTimeInterval(301)))
    }

    func testClearRemovesEntry() {
        let store = SnoozeStore()
        store.snooze(eventID: "e1", minutes: 5, now: now)
        store.clear(eventID: "e1")
        XCTAssertNil(store.snoozedUntil(eventID: "e1"))
    }

    func testClearExpiredDropsOnlyPastEntries() {
        let store = SnoozeStore()
        store.snooze(eventID: "past", minutes: 1, now: now)
        store.snooze(eventID: "future", minutes: 10, now: now)
        store.clearExpired(now: now.addingTimeInterval(120))
        XCTAssertNil(store.snoozedUntil(eventID: "past"))
        XCTAssertNotNil(store.snoozedUntil(eventID: "future"))
    }
}
