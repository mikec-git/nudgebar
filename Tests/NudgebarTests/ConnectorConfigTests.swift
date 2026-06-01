import XCTest
import NudgebarCore
@testable import Nudgebar

final class ConnectorConfigTests: XCTestCase {
    func testRedirectUsesAppScheme() {
        let result = ConnectorConfig.redirect(for: .calendly, clientID: "any")
        XCTAssertEqual(result.scheme, "com.local.nudgebar")
        XCTAssertEqual(result.uri.absoluteString, "com.local.nudgebar://oauth")
    }
}

final class CalendarDateParsingTests: XCTestCase {
    func testParsesVariants() {
        XCTAssertNotNil(CalendarDateParsing.parse("2026-01-15T10:00:00Z"))
        XCTAssertNotNil(CalendarDateParsing.parse("2026-01-15T10:00:00.500Z"))
        XCTAssertNotNil(CalendarDateParsing.parse("2026-01-15T10:00:00.000000Z")) // 6-digit fractional
        XCTAssertNotNil(CalendarDateParsing.parse("2026-01-15T10:00:00-0800"))     // no-colon offset
        XCTAssertNotNil(CalendarDateParsing.parse("2026-01-16"))                   // date-only
        XCTAssertNil(CalendarDateParsing.parse("not-a-date"))
    }
}
