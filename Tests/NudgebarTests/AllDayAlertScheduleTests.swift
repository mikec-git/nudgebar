import XCTest
import NudgebarCore
@testable import Nudgebar

final class AllDayAlertScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func allDayEvent(on dateString: String) -> AlertCandidate {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        let start = formatter.date(from: dateString)!
        return AlertOccurrence(
            id: "ad", title: "Holiday",
            startDate: start, endDate: start.addingTimeInterval(86_400),
            calendarTitle: "Personal", isAllDay: true
        )
    }

    func testFireDateDayOf() {
        let fire = AllDayAlertSchedule.fireDate(for: allDayEvent(on: "2026-01-15"), hour: 9, minute: 0, dayOffset: 0, calendar: calendar)
        let components = calendar.dateComponents([.day, .hour, .minute], from: fire)
        XCTAssertEqual(components.day, 15)
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 0)
    }

    func testFireDateDayBefore() {
        let fire = AllDayAlertSchedule.fireDate(for: allDayEvent(on: "2026-01-15"), hour: 18, minute: 30, dayOffset: 1, calendar: calendar)
        let components = calendar.dateComponents([.day, .hour, .minute], from: fire)
        XCTAssertEqual(components.day, 14)
        XCTAssertEqual(components.hour, 18)
        XCTAssertEqual(components.minute, 30)
    }
}
