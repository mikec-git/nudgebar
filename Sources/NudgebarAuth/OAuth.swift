import NudgebarCore
import CryptoKit
import Foundation

public struct OAuthProviderMetadata: Codable, Equatable, Sendable {
    public let providerID: ProviderID
    public let authorizationEndpoint: URL
    public let tokenEndpoint: URL
    public let clientID: String
    public let redirectURI: URL
    public let scopes: [String]
    public let usesPKCE: Bool
    public let embedsClientSecret: Bool

    public init(
        providerID: ProviderID,
        authorizationEndpoint: URL,
        tokenEndpoint: URL,
        clientID: String,
        redirectURI: URL,
        scopes: [String],
        usesPKCE: Bool = true,
        embedsClientSecret: Bool = false
    ) {
        self.providerID = providerID
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.scopes = scopes
        self.usesPKCE = usesPKCE
        self.embedsClientSecret = embedsClientSecret
    }
}

public struct PKCEChallenge: Codable, Equatable, Sendable {
    public let verifier: String
    public let challenge: String
    public let method: String

    public init(verifier: String) {
        self.verifier = verifier
        self.challenge = Self.challenge(for: verifier)
        self.method = "S256"
    }

    private static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }
}

public enum ProviderAuthCatalog {
    public static func metadata(
        providerID: ProviderID,
        clientID: String,
        redirectURI: URL
    ) -> OAuthProviderMetadata? {
        switch providerID {
        case .googleCalendar:
            return OAuthProviderMetadata(
                providerID: providerID,
                authorizationEndpoint: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
                tokenEndpoint: URL(string: "https://oauth2.googleapis.com/token")!,
                clientID: clientID,
                redirectURI: redirectURI,
                scopes: [
                    "https://www.googleapis.com/auth/calendar.calendarlist.readonly",
                    "https://www.googleapis.com/auth/calendar.events.readonly"
                ]
            )
        case .microsoftGraph:
            return OAuthProviderMetadata(
                providerID: providerID,
                authorizationEndpoint: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!,
                tokenEndpoint: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!,
                clientID: clientID,
                redirectURI: redirectURI,
                scopes: [
                    "offline_access",
                    "Calendars.Read"
                ]
            )
        case .calendly:
            return OAuthProviderMetadata(
                providerID: providerID,
                authorizationEndpoint: URL(string: "https://auth.calendly.com/oauth/authorize")!,
                tokenEndpoint: URL(string: "https://auth.calendly.com/oauth/token")!,
                clientID: clientID,
                redirectURI: redirectURI,
                scopes: ["default"]
            )
        case .eventKit, .calDAV, .calCom, .acuity:
            return nil
        }
    }
}

public enum CredentialValidation {
    public static func requireHTTPS(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
    }

    public static func calDAVReference(
        accountID: String,
        host: String
    ) -> CredentialReference {
        CredentialReference(
            service: "Nudgebar.CalDAV.\(host)",
            account: accountID,
            kind: CredentialKind.calDAVPassword.rawValue
        )
    }

    public static func acuityAPIKeyReference(accountID: String) -> CredentialReference {
        CredentialReference(
            service: "Nudgebar.Acuity",
            account: accountID,
            kind: CredentialKind.apiKey.rawValue
        )
    }

    public static func basicAuthReference(
        providerID: ProviderID,
        accountID: String
    ) -> CredentialReference {
        CredentialReference(
            service: "Nudgebar.\(providerID.rawValue).BasicAuth",
            account: accountID,
            kind: CredentialKind.basicAuthPassword.rawValue
        )
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
