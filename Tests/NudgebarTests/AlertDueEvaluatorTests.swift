import XCTest
import NudgebarCore
@testable import Nudgebar

final class AlertDueEvaluatorTests: XCTestCase {
    // Fixed instant (2026-01-15 10:00 UTC) so timed offsets and all-day clock math
    // are deterministic regardless of the machine's time zone.
    private let now = AlertDueEvaluatorTests.utc("2026-01-15 10:00")

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private static func utc(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: string)!
    }

    private func timed(
        _ id: String,
        startOffset: TimeInterval,
        durationMinutes: Double = 30,
        status: AlertOccurrenceStatus = .confirmed,
        sourceID: String = "default"
    ) -> AlertCandidate {
        let start = now.addingTimeInterval(startOffset)
        return AlertOccurrence(
            id: id, title: id,
            startDate: start,
            endDate: start.addingTimeInterval(durationMinutes * 60),
            calendarTitle: "Work",
            sourceID: sourceID,
            status: status
        )
    }

    private func allDay(_ id: String, date dateString: String) -> AlertCandidate {
        let start = Self.utc("\(dateString) 00:00")
        return AlertOccurrence(
            id: id, title: id,
            startDate: start,
            endDate: start.addingTimeInterval(86_400),
            calendarTitle: "Personal",
            isAllDay: true
        )
    }

    // MARK: - rescheduledIDs

    func testReschedulesWhenStartChanged() {
        let moved = timed("a", startOffset: 600) // now moved to +10m
        let ids = AlertDueEvaluator.rescheduledIDs(
            candidates: [moved],
            alertedEvents: ["a": now.addingTimeInterval(300)] // was alerted for +5m
        )
        XCTAssertEqual(ids, ["a"])
    }

    func testNoRescheduleWhenStartUnchanged() {
        let event = timed("a", startOffset: 300)
        let ids = AlertDueEvaluator.rescheduledIDs(candidates: [event], alertedEvents: ["a": event.startDate])
        XCTAssertTrue(ids.isEmpty)
    }

    func testNoRescheduleWhenNeverAlerted() {
        let ids = AlertDueEvaluator.rescheduledIDs(candidates: [timed("a", startOffset: 300)], alertedEvents: [:])
        XCTAssertTrue(ids.isEmpty)
    }

    // MARK: - suppressedIDs

    func testSuppressedIncludesAlertedAndActiveSnooze() {
        let suppressed = AlertDueEvaluator.suppressedIDs(
            alertedEvents: ["a": now],
            snoozedUntil: ["b": now.addingTimeInterval(120)],
            now: now
        )
        XCTAssertEqual(suppressed, ["a", "b"])
    }

    func testSuppressedExcludesExpiredSnooze() {
        let suppressed = AlertDueEvaluator.suppressedIDs(
            alertedEvents: [:],
            snoozedUntil: ["b": now.addingTimeInterval(-1)],
            now: now
        )
        XCTAssertTrue(suppressed.isEmpty)
    }

    // MARK: - timedDue

    func testDueWithinLeadWindow() {
        let due = AlertDueEvaluator.timedDue(
            candidates: [timed("a", startOffset: 5 * 60)],
            now: now, suppressed: [], leadMinutes: { _ in 5 }
        )
        XCTAssertEqual(due.map(\.id), ["a"])
    }

    func testNotDueBeyondLeadWindow() {
        let due = AlertDueEvaluator.timedDue(
            candidates: [timed("a", startOffset: 6 * 60)],
            now: now, suppressed: [], leadMinutes: { _ in 5 }
        )
        XCTAssertTrue(due.isEmpty)
    }

    func testNotDueAfterStart() {
        let due = AlertDueEvaluator.timedDue(
            candidates: [timed("a", startOffset: -1)],
            now: now, suppressed: [], leadMinutes: { _ in 5 }
        )
        XCTAssertTrue(due.isEmpty)
    }

    func testAllDayNeverTimedDue() {
        let due = AlertDueEvaluator.timedDue(
            candidates: [allDay("a", date: "2026-01-15")],
            now: now, suppressed: [], leadMinutes: { _ in 5 }
        )
        XCTAssertTrue(due.isEmpty)
    }

    func testTentativeNotDue() {
        let due = AlertDueEvaluator.timedDue(
            candidates: [timed("a", startOffset: 60, status: .tentative)],
            now: now, suppressed: [], leadMinutes: { _ in 5 }
        )
        XCTAssertTrue(due.isEmpty)
    }

    func testSuppressedNotDue() {
        let due = AlertDueEvaluator.timedDue(
            candidates: [timed("a", startOffset: 60)],
            now: now, suppressed: ["a"], leadMinutes: { _ in 5 }
        )
        XCTAssertTrue(due.isEmpty)
    }

    func testDueSortedBySoonestStart() {
        let due = AlertDueEvaluator.timedDue(
            candidates: [timed("late", startOffset: 240), timed("soon", startOffset: 60)],
            now: now, suppressed: [], leadMinutes: { _ in 10 }
        )
        XCTAssertEqual(due.map(\.id), ["soon", "late"])
    }

    func testLeadZeroFiresAtStart() {
        let due = AlertDueEvaluator.timedDue(
            candidates: [timed("a", startOffset: 0)],
            now: now, suppressed: [], leadMinutes: { _ in 0 }
        )
        XCTAssertEqual(due.map(\.id), ["a"])
    }

    func testPerEventLeadHonored() {
        // Both 8 minutes out; only the one with a >= 8m lead is due.
        let candidates = [timed("short", startOffset: 8 * 60), timed("long", startOffset: 8 * 60)]
        let due = AlertDueEvaluator.timedDue(
            candidates: candidates, now: now, suppressed: [],
            leadMinutes: { $0.id == "long" ? 15 : 5 }
        )
        XCTAssertEqual(due.map(\.id), ["long"])
    }

    // MARK: - allDayDue

    func testAllDayDueAfterFireTime() {
        let due = AlertDueEvaluator.allDayDue(
            candidates: [allDay("ad", date: "2026-01-15")],
            now: now, suppressed: [], hour: 9, minute: 0, dayOffset: 0, calendar: Self.utcCalendar
        )
        XCTAssertEqual(due.map(\.id), ["ad"]) // fire 09:00, now 10:00
    }

    func testAllDayNotDueBeforeFireTime() {
        let due = AlertDueEvaluator.allDayDue(
            candidates: [allDay("ad", date: "2026-01-15")],
            now: now, suppressed: [], hour: 11, minute: 0, dayOffset: 0, calendar: Self.utcCalendar
        )
        XCTAssertTrue(due.isEmpty) // fire 11:00, now 10:00
    }

    func testAllDayNotDueOnceEnded() {
        let due = AlertDueEvaluator.allDayDue(
            candidates: [allDay("ad", date: "2026-01-13")], // ended before now
            now: now, suppressed: [], hour: 9, minute: 0, dayOffset: 0, calendar: Self.utcCalendar
        )
        XCTAssertTrue(due.isEmpty)
    }

    func testAllDaySuppressedNotDue() {
        let due = AlertDueEvaluator.allDayDue(
            candidates: [allDay("ad", date: "2026-01-15")],
            now: now, suppressed: ["ad"], hour: 9, minute: 0, dayOffset: 0, calendar: Self.utcCalendar
        )
        XCTAssertTrue(due.isEmpty)
    }

    // MARK: - Integration: the "didn't alert after editing" bug

    func testEditedEventReArmsAndBecomesDue() {
        // Event was alerted an hour ago at its old time, then moved to 3m from now
        // (inside a 5m lead). Without re-arming it stays suppressed; after re-arming
        // it becomes due again — exactly the reported bug.
        let moved = timed("x", startOffset: 3 * 60)
        var alerted: [String: Date] = ["x": now.addingTimeInterval(-3600)]
        let lead: (AlertCandidate) -> Int = { _ in 5 }

        let beforeSuppressed = AlertDueEvaluator.suppressedIDs(alertedEvents: alerted, snoozedUntil: [:], now: now)
        XCTAssertTrue(
            AlertDueEvaluator.timedDue(candidates: [moved], now: now, suppressed: beforeSuppressed, leadMinutes: lead).isEmpty,
            "Moved event should be suppressed before re-arming"
        )

        for id in AlertDueEvaluator.rescheduledIDs(candidates: [moved], alertedEvents: alerted) {
            alerted.removeValue(forKey: id)
        }

        let afterSuppressed = AlertDueEvaluator.suppressedIDs(alertedEvents: alerted, snoozedUntil: [:], now: now)
        let due = AlertDueEvaluator.timedDue(candidates: [moved], now: now, suppressed: afterSuppressed, leadMinutes: lead)
        XCTAssertEqual(due.map(\.id), ["x"], "Moved event should alert again at its new time")
    }

    // MARK: - Integration: per-calendar lead override via real AlertPreferences

    @MainActor
    func testPerCalendarLeadOverrideMakesEventDue() {
        let suiteName = "AlertDueEvaluatorTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = AlertPreferences(defaults: defaults)
        preferences.leadMinutes = 5
        let lead: (AlertCandidate) -> Int = { preferences.effectiveSettings(for: $0).leadMinutes }

        let event = timed("x", startOffset: 12 * 60, sourceID: "cal-1") // 12m out

        XCTAssertTrue(
            AlertDueEvaluator.timedDue(candidates: [event], now: now, suppressed: [], leadMinutes: lead).isEmpty,
            "With the 5m global lead a 12m-out event is not due"
        )

        preferences.setRule(CalendarAlertRule(leadMinutesOverride: 15, soundOverride: nil), for: "cal-1")
        XCTAssertEqual(
            AlertDueEvaluator.timedDue(candidates: [event], now: now, suppressed: [], leadMinutes: lead).map(\.id),
            ["x"],
            "A 15m per-calendar override should make the 12m-out event due"
        )
    }
}
