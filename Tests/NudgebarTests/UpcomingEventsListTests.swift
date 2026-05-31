import XCTest
import NudgebarCore
@testable import Nudgebar

final class UpcomingEventsListTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    // Fixed reference point well away from a day boundary: 2026-01-15 10:00 UTC.
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 10, minute: 0))!
    }

    private func event(_ id: String, offsetHours: Double) -> AlertCandidate {
        let start = now.addingTimeInterval(offsetHours * 3600)
        return AlertOccurrence(
            id: id,
            title: id,
            startDate: start,
            endDate: start.addingTimeInterval(1800),
            calendarTitle: "Work"
        )
    }

    func testFilterExcludesPastAndBeyondTomorrowAndSorts() {
        let events = [
            event("late", offsetHours: 50),    // beyond end of tomorrow
            event("tomorrow", offsetHours: 26),
            event("past", offsetHours: -1),
            event("today", offsetHours: 1)
        ]
        let result = UpcomingEventsList.filter(events, now: now, calendar: calendar)
        XCTAssertEqual(result.map(\.id), ["today", "tomorrow"])
    }

    func testCapAtMaxEntries() {
        let events = (0..<30).map { event("e\($0)", offsetHours: Double($0) * 0.1 + 0.1) }
        let result = UpcomingEventsList.filter(events, now: now, calendar: calendar)
        XCTAssertEqual(result.count, UpcomingEventsList.maxEntries)
    }

    func testGroupingTodayTomorrow() {
        let events = [event("today", offsetHours: 1), event("tomorrow", offsetHours: 26)]
        let grouped = UpcomingEventsList.group(events, now: now, calendar: calendar)
        XCTAssertEqual(grouped.first { $0.id == "today" }?.group, .today)
        XCTAssertEqual(grouped.first { $0.id == "tomorrow" }?.group, .tomorrow)
    }

    func testWasTruncated() {
        let few = [event("a", offsetHours: 1)]
        XCTAssertFalse(UpcomingEventsList.wasTruncated(few, now: now, calendar: calendar))
        let many = (0..<30).map { event("e\($0)", offsetHours: Double($0) * 0.1 + 0.1) }
        XCTAssertTrue(UpcomingEventsList.wasTruncated(many, now: now, calendar: calendar))
    }
}
