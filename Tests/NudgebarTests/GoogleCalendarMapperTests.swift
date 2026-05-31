import XCTest
import NudgebarCore
@testable import Nudgebar

final class GoogleCalendarMapperTests: XCTestCase {
    private let account = ConnectedAccount(id: "acc1", providerID: .googleCalendar, displayName: "Test")
    private var source: CalendarSource {
        CalendarSource(id: "primary", title: "Personal", sourceTitle: "Google Calendar", providerID: .googleCalendar, accountID: "acc1", externalID: "primary")
    }

    func testParsesCalendarList() {
        let json = #"{"items":[{"id":"primary","summary":"Personal"},{"id":"work@x.com","summary":"Work"}]}"#.data(using: .utf8)!
        let sources = GoogleCalendarMapper.sources(from: json, account: account)
        XCTAssertEqual(sources.map(\.id), ["primary", "work@x.com"])
        XCTAssertEqual(sources.first?.title, "Personal")
    }

    func testParsesEvents() throws {
        let json = """
        {"items":[
          {"id":"e1","summary":"Standup","status":"confirmed","location":"Room 4","hangoutLink":"https://meet.google.com/abc","organizer":{"displayName":"Alex"},"start":{"dateTime":"2026-01-15T10:00:00Z"},"end":{"dateTime":"2026-01-15T10:30:00Z"}},
          {"id":"e2","summary":"Holiday","status":"confirmed","start":{"date":"2026-01-16"},"end":{"date":"2026-01-17"}},
          {"id":"e3","summary":"Old","status":"cancelled","start":{"dateTime":"2026-01-15T12:00:00Z"},"end":{"dateTime":"2026-01-15T12:30:00Z"}}
        ]}
        """.data(using: .utf8)!

        let occurrences = try GoogleCalendarMapper.occurrences(from: json, account: account, source: source)
        XCTAssertEqual(occurrences.count, 3)

        let standup = occurrences[0]
        XCTAssertEqual(standup.title, "Standup")
        XCTAssertEqual(standup.location, "Room 4")
        XCTAssertEqual(standup.organizer, "Alex")
        XCTAssertEqual(standup.meetingURL?.host, "meet.google.com")
        XCTAssertFalse(standup.isAllDay)
        XCTAssertEqual(standup.providerID, .googleCalendar)
        XCTAssertEqual(standup.accountID, "acc1")

        XCTAssertTrue(occurrences[1].isAllDay)
        XCTAssertEqual(occurrences[2].status, .cancelled)
    }

    func testParseDateHandlesISOAndDateOnly() {
        XCTAssertNotNil(GoogleCalendarMapper.parseDate("2026-01-15T10:00:00Z"))
        XCTAssertNotNil(GoogleCalendarMapper.parseDate("2026-01-15T10:00:00.500Z"))
        XCTAssertNotNil(GoogleCalendarMapper.parseDate("2026-01-16"))
        XCTAssertNil(GoogleCalendarMapper.parseDate("not-a-date"))
    }
}
