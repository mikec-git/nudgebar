import XCTest
import NudgebarCore
@testable import Nudgebar

final class CalComMapperTests: XCTestCase {
    private let account = ConnectedAccount(id: "acc1", providerID: .calCom, displayName: "Test")
    private var source: CalendarSource {
        CalendarSource(id: "acc1", title: "Cal.com", sourceTitle: "Cal.com", providerID: .calCom, accountID: "acc1", externalID: "acc1")
    }
    private let windowStart = Date(timeIntervalSince1970: 1_768_000_000)
    private let windowEnd = Date(timeIntervalSince1970: 1_769_000_000)

    func testParsesBookingsWithinWindow() throws {
        let json = """
        {"bookings":[
          {"uid":"BK1","title":"30 Min Meeting","startTime":"2026-01-15T10:00:00.000Z","endTime":"2026-01-15T10:30:00.000Z","status":"accepted","location":"https://meet.example.com/x"},
          {"uid":"BK2","title":"Way later","startTime":"2030-01-01T10:00:00.000Z","endTime":"2030-01-01T10:30:00.000Z","status":"accepted"}
        ]}
        """.data(using: .utf8)!
        let occurrences = try CalComMapper.occurrences(from: json, account: account, source: source, windowStart: windowStart, windowEnd: windowEnd)
        XCTAssertEqual(occurrences.count, 1)
        XCTAssertEqual(occurrences[0].title, "30 Min Meeting")
        XCTAssertEqual(occurrences[0].externalID, "BK1")
        XCTAssertEqual(occurrences[0].meetingURL?.host, "meet.example.com")
    }
}

final class AcuityMapperTests: XCTestCase {
    private let account = ConnectedAccount(id: "acc1", providerID: .acuity, displayName: "Test")
    private var source: CalendarSource {
        CalendarSource(id: "acc1", title: "Acuity", sourceTitle: "Acuity Scheduling", providerID: .acuity, accountID: "acc1", externalID: "acc1")
    }

    func testParsesAppointments() throws {
        let json = """
        [{"id":42,"firstName":"Sam","lastName":"Lee","type":"Consult","datetime":"2026-01-15T10:00:00-0800","duration":"30","location":"Office"}]
        """.data(using: .utf8)!
        let windowStart = Date(timeIntervalSince1970: 1_768_000_000)
        let windowEnd = Date(timeIntervalSince1970: 1_769_000_000)
        let occurrences = try AcuityMapper.occurrences(from: json, account: account, source: source, windowStart: windowStart, windowEnd: windowEnd)
        XCTAssertEqual(occurrences.count, 1)
        XCTAssertEqual(occurrences[0].title, "Consult · Sam Lee")
        XCTAssertEqual(occurrences[0].externalID, "42")
        XCTAssertEqual(occurrences[0].location, "Office")
        // 30-minute duration applied
        XCTAssertEqual(occurrences[0].endDate.timeIntervalSince(occurrences[0].startDate), 1800)
    }
}
