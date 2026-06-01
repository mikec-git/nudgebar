import XCTest
import NudgebarCore
@testable import Nudgebar

final class CalendlyMapperTests: XCTestCase {
    private let account = ConnectedAccount(id: "acc1", providerID: .calendly, displayName: "Test")
    private var source: CalendarSource {
        CalendarSource(id: "u1", title: "Me", sourceTitle: "Calendly", providerID: .calendly, accountID: "acc1", externalID: "u1")
    }

    func testParsesUserSource() {
        let json = #"{"resource":{"uri":"https://api.calendly.com/users/U1","name":"Me"}}"#.data(using: .utf8)!
        let source = CalendlyMapper.source(from: json, account: account)
        XCTAssertEqual(source?.externalID, "https://api.calendly.com/users/U1")
        XCTAssertEqual(source?.title, "Calendly")
    }

    func testParsesScheduledEvents() throws {
        let json = """
        {"collection":[{"uri":"https://api.calendly.com/scheduled_events/EV1","name":"Intro call","status":"active",
        "start_time":"2026-01-15T10:00:00.000000Z","end_time":"2026-01-15T10:30:00.000000Z",
        "location":{"type":"zoom","join_url":"https://zoom.us/j/1"}}]}
        """.data(using: .utf8)!
        let occurrences = try CalendlyMapper.occurrences(from: json, account: account, source: source)
        XCTAssertEqual(occurrences.count, 1)
        XCTAssertEqual(occurrences[0].title, "Intro call")
        XCTAssertEqual(occurrences[0].externalID, "EV1")
        XCTAssertEqual(occurrences[0].meetingURL?.host, "zoom.us")
        XCTAssertEqual(occurrences[0].providerID, .calendly)
    }
}
