import XCTest
@testable import Nudgebar

final class ICalParserTests: XCTestCase {
    func testParsesVEvents() {
        let ical = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:evt-1
        SUMMARY:Team sync
        DTSTART:20260115T100000Z
        DTEND:20260115T103000Z
        LOCATION:Room 9
        ORGANIZER;CN=Alex Rivera:mailto:alex@example.com
        STATUS:CONFIRMED
        END:VEVENT
        BEGIN:VEVENT
        UID:evt-2
        SUMMARY:Holiday
        DTSTART;VALUE=DATE:20260116
        END:VEVENT
        END:VCALENDAR
        """
        let events = ICalParser.events(from: ical)
        XCTAssertEqual(events.count, 2)

        let sync = events[0]
        XCTAssertEqual(sync.uid, "evt-1")
        XCTAssertEqual(sync.summary, "Team sync")
        XCTAssertEqual(sync.location, "Room 9")
        XCTAssertEqual(sync.organizer, "Alex Rivera")
        XCTAssertFalse(sync.isAllDay)
        XCTAssertFalse(sync.cancelled)
        XCTAssertEqual(sync.end.timeIntervalSince(sync.start), 1800)

        XCTAssertTrue(events[1].isAllDay)
    }

    func testUnfoldsContinuationLines() {
        let ical = """
        BEGIN:VEVENT
        UID:evt-3
        SUMMARY:A very long title that has been
          folded across two lines
        DTSTART:20260115T100000Z
        END:VEVENT
        """
        let events = ICalParser.events(from: ical)
        XCTAssertEqual(events.first?.summary, "A very long title that has been folded across two lines")
    }

    func testCancelledStatus() {
        let ical = """
        BEGIN:VEVENT
        UID:evt-4
        SUMMARY:Cancelled meeting
        DTSTART:20260115T100000Z
        STATUS:CANCELLED
        END:VEVENT
        """
        XCTAssertTrue(ICalParser.events(from: ical).first?.cancelled == true)
    }

    func testParseDateVariants() {
        XCTAssertNotNil(ICalParser.parseDate("20260115T100000Z", tzid: nil))
        XCTAssertEqual(ICalParser.parseDate("20260116", tzid: nil)?.1, true) // all-day flag
        XCTAssertNotNil(ICalParser.parseDate("20260115T100000", tzid: "America/Los_Angeles"))
    }
}
