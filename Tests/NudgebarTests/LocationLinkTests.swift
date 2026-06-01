import XCTest
@testable import Nudgebar

final class LocationLinkTests: XCTestCase {
    func testWholeStringURL() {
        XCTAssertEqual(
            LocationLink.firstURL(in: "https://app.cal.com/video/abc")?.absoluteString,
            "https://app.cal.com/video/abc"
        )
    }

    func testEmbeddedURL() {
        XCTAssertEqual(LocationLink.firstURL(in: "Room A — https://zoom.us/j/123")?.host, "zoom.us")
    }

    func testPlainTextHasNoLink() {
        XCTAssertNil(LocationLink.firstURL(in: "Conference Room A"))
    }

    func testEmptyHasNoLink() {
        XCTAssertNil(LocationLink.firstURL(in: ""))
    }
}
