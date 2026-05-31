import XCTest
@testable import Nudgebar

final class ConferenceLinkTests: XCTestCase {
    func testZoomMeetingURL() {
        let link = ConferenceLinkResolver.resolve(meetingURL: URL(string: "https://acme.zoom.us/j/123"))
        XCTAssertEqual(link?.type, .zoom)
    }

    func testGoogleMeetURL() {
        let link = ConferenceLinkResolver.resolve(meetingURL: URL(string: "https://meet.google.com/abc-defg-hij"))
        XCTAssertEqual(link?.type, .googleMeet)
    }

    func testTeamsURL() {
        let link = ConferenceLinkResolver.resolve(meetingURL: URL(string: "https://teams.microsoft.com/l/meetup-join/x"))
        XCTAssertEqual(link?.type, .microsoftTeams)
    }

    func testGenericMeetingURL() {
        let link = ConferenceLinkResolver.resolve(meetingURL: URL(string: "https://meet.example.com/room"))
        XCTAssertEqual(link?.type, .generic)
    }

    func testKnownProviderFoundInLocationText() {
        let link = ConferenceLinkResolver.resolve(
            meetingURL: nil,
            location: "Join at https://acme.zoom.us/j/999 (room 4)"
        )
        XCTAssertEqual(link?.type, .zoom)
    }

    func testGenericLinkInLocationIsNotTreatedAsConference() {
        let link = ConferenceLinkResolver.resolve(
            meetingURL: nil,
            location: "https://maps.example.com/place"
        )
        XCTAssertNil(link)
    }

    func testNoLink() {
        XCTAssertNil(ConferenceLinkResolver.resolve(meetingURL: nil, location: "Room 7", notes: "Bring laptop"))
    }
}
