import NudgebarAuth
import NudgebarCore
import XCTest

final class AuthBoundaryTests: XCTestCase {
    func testPKCEChallengeUsesS256() {
        let challenge = PKCEChallenge(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")

        XCTAssertEqual(challenge.method, "S256")
        XCTAssertEqual(challenge.challenge, "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func testOAuthMetadataDoesNotEmbedClientSecretAndUsesReadScopes() throws {
        let redirectURI = URL(string: "alertbar://oauth")!
        let google = try XCTUnwrap(
            ProviderAuthCatalog.metadata(
                providerID: .googleCalendar,
                clientID: "client-id",
                redirectURI: redirectURI
            )
        )
        let microsoft = try XCTUnwrap(
            ProviderAuthCatalog.metadata(
                providerID: .microsoftGraph,
                clientID: "client-id",
                redirectURI: redirectURI
            )
        )

        XCTAssertTrue(google.usesPKCE)
        XCTAssertFalse(google.embedsClientSecret)
        XCTAssertTrue(google.scopes.allSatisfy { $0.contains("readonly") })
        XCTAssertTrue(microsoft.scopes.contains("Calendars.Read"))
        XCTAssertTrue(microsoft.scopes.contains("offline_access"))
        XCTAssertFalse(microsoft.embedsClientSecret)
    }

    func testCalDAVAndAcuityCredentialsUseReferencesOnly() {
        XCTAssertTrue(CredentialValidation.requireHTTPS(URL(string: "https://caldav.example.com")!))
        XCTAssertFalse(CredentialValidation.requireHTTPS(URL(string: "http://caldav.example.com")!))

        let caldav = CredentialValidation.calDAVReference(accountID: "account", host: "caldav.example.com")
        let acuity = CredentialValidation.acuityAPIKeyReference(accountID: "account")

        XCTAssertEqual(caldav.kind, CredentialKind.calDAVPassword.rawValue)
        XCTAssertEqual(acuity.kind, CredentialKind.apiKey.rawValue)
    }

    func testCredentialStoreCanUseNonKeychainFakeForFixtures() throws {
        let store = InMemoryCredentialStore()
        let reference = CredentialReference(service: "Nudgebar.Test", account: "fixture", kind: CredentialKind.apiKey.rawValue)
        let record = CredentialRecord(reference: reference, kind: .apiKey, secret: Data("secret".utf8))

        try store.save(record)

        XCTAssertEqual(try store.read(reference: reference)?.secret, Data("secret".utf8))
    }
}
