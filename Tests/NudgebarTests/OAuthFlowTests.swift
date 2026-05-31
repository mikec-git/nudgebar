import XCTest
import NudgebarAuth
import NudgebarCore
@testable import Nudgebar

final class OAuthFlowTests: XCTestCase {
    private func metadata() -> OAuthProviderMetadata {
        ProviderAuthCatalog.metadata(
            providerID: .googleCalendar,
            clientID: "client-123",
            redirectURI: URL(string: "com.local.nudgebar://oauth")!
        )!
    }

    func testAuthorizationURLContainsPKCEAndParams() {
        let url = OAuthFlow.authorizationURL(metadata: metadata(), challenge: "CHAL", state: "STATE", extra: ["access_type": "offline"])
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        XCTAssertEqual(value("client_id"), "client-123")
        XCTAssertEqual(value("response_type"), "code")
        XCTAssertEqual(value("code_challenge"), "CHAL")
        XCTAssertEqual(value("code_challenge_method"), "S256")
        XCTAssertEqual(value("state"), "STATE")
        XCTAssertEqual(value("access_type"), "offline")
        XCTAssertEqual(value("redirect_uri"), "com.local.nudgebar://oauth")
    }

    func testParseCallbackReturnsCode() throws {
        let url = URL(string: "com.local.nudgebar://oauth?code=AUTHCODE&state=STATE")!
        XCTAssertEqual(try OAuthFlow.parseCallback(url, expectedState: "STATE"), "AUTHCODE")
    }

    func testParseCallbackRejectsStateMismatch() {
        let url = URL(string: "com.local.nudgebar://oauth?code=X&state=WRONG")!
        XCTAssertThrowsError(try OAuthFlow.parseCallback(url, expectedState: "STATE")) { error in
            XCTAssertEqual(error as? OAuthError, .stateMismatch)
        }
    }

    func testParseCallbackSurfacesError() {
        let url = URL(string: "com.local.nudgebar://oauth?error=access_denied")!
        XCTAssertThrowsError(try OAuthFlow.parseCallback(url, expectedState: "STATE"))
    }

    func testParseTokenResponse() throws {
        let json = #"{"access_token":"AT","refresh_token":"RT","expires_in":3600}"#.data(using: .utf8)!
        let tokens = try OAuthFlow.parseTokenResponse(json)
        XCTAssertEqual(tokens.accessToken, "AT")
        XCTAssertEqual(tokens.refreshToken, "RT")
        XCTAssertNotNil(tokens.expiresAt)
    }

    func testRandomTokenIsURLSafe() {
        let token = OAuthFlow.randomToken(32)
        XCTAssertFalse(token.isEmpty)
        XCTAssertFalse(token.contains("+"))
        XCTAssertFalse(token.contains("/"))
        XCTAssertFalse(token.contains("="))
    }
}
