import XCTest
import NudgebarCore
@testable import Nudgebar

final class ConnectorConfigTests: XCTestCase {
    func testGoogleUsesReverseDNSRedirect() {
        let result = ConnectorConfig.redirect(for: .googleCalendar, clientID: "123-abc.apps.googleusercontent.com")
        XCTAssertEqual(result.scheme, "com.googleusercontent.apps.123-abc")
        XCTAssertEqual(result.uri.absoluteString, "com.googleusercontent.apps.123-abc:/oauth")
    }

    func testMicrosoftUsesAppScheme() {
        let result = ConnectorConfig.redirect(for: .microsoftGraph, clientID: "any-guid")
        XCTAssertEqual(result.scheme, "com.local.nudgebar")
        XCTAssertEqual(result.uri.absoluteString, "com.local.nudgebar://oauth")
    }
}
