import XCTest
import NudgebarCore
@testable import Nudgebar

final class StatusItemTitleFormatterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_768_471_200)

    private func event(_ title: String, startOffset: TimeInterval) -> AlertCandidate {
        AlertOccurrence(
            id: "e",
            title: title,
            startDate: now.addingTimeInterval(startOffset),
            endDate: now.addingTimeInterval(startOffset + 1800),
            calendarTitle: "Work"
        )
    }

    func testNilEventIsEmpty() {
        XCTAssertEqual(StatusItemTitleFormatter.title(for: nil, now: now), .empty)
    }

    func testPastEventIsEmpty() {
        let result = StatusItemTitleFormatter.title(for: event("Standup", startOffset: -60), now: now)
        XCTAssertEqual(result, .empty)
    }

    func testMinutesCountdownAndWarningProximity() {
        let result = StatusItemTitleFormatter.title(for: event("Standup", startOffset: 12 * 60), now: now)
        XCTAssertEqual(result.text, "Standup · 12m")
        XCTAssertEqual(result.proximity, .warning)
    }

    func testImminentCountdownAndUrgentProximity() {
        let result = StatusItemTitleFormatter.title(for: event("Standup", startOffset: 20), now: now)
        XCTAssertEqual(result.text, "Standup · starts in <30s")
        XCTAssertEqual(result.proximity, .urgent)
    }

    func testProximityBuckets() {
        XCTAssertEqual(StatusItemTitleFormatter.proximityBucket(secondsUntilStart: 4 * 60), .urgent)
        XCTAssertEqual(StatusItemTitleFormatter.proximityBucket(secondsUntilStart: 10 * 60), .warning)
        XCTAssertEqual(StatusItemTitleFormatter.proximityBucket(secondsUntilStart: 30 * 60), .default)
    }

    func testMiddleTruncation() {
        let long = "Quarterly planning sync with the platform team"
        let truncated = StatusItemTitleFormatter.truncate(long, to: 24)
        XCTAssertEqual(truncated.count, 24)
        XCTAssertTrue(truncated.contains("…"))
        XCTAssertTrue(truncated.hasPrefix("Quarterly"))
    }

    func testTickInterval() {
        XCTAssertEqual(StatusItemTitleFormatter.tickInterval(secondsUntilStart: 30 * 60), 1)
        XCTAssertEqual(StatusItemTitleFormatter.tickInterval(secondsUntilStart: 90 * 60), 60)
        XCTAssertEqual(StatusItemTitleFormatter.tickInterval(secondsUntilStart: nil), 60)
        XCTAssertEqual(StatusItemTitleFormatter.tickInterval(secondsUntilStart: -5), 60)
    }
}
