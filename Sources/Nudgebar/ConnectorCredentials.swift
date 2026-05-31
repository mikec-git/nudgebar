import NudgebarAuth
import NudgebarCore
import Foundation

/// Keychain references for connector credentials.
enum ConnectorCredentials {
    static func oauthRefreshReference(providerID: ProviderID, accountID: String) -> CredentialReference {
        CredentialReference(
            service: "Nudgebar.\(providerID.rawValue).OAuth",
            account: accountID,
            kind: CredentialKind.oauthRefreshToken.rawValue
        )
    }

    static func apiKeyReference(providerID: ProviderID, accountID: String) -> CredentialReference {
        CredentialReference(
            service: "Nudgebar.\(providerID.rawValue).APIKey",
            account: accountID,
            kind: CredentialKind.apiKey.rawValue
        )
    }

    static func save(_ secret: String, reference: CredentialReference, kind: CredentialKind, store: CredentialStore = KeychainCredentialStore()) throws {
        try store.save(CredentialRecord(reference: reference, kind: kind, secret: Data(secret.utf8)))
    }

    static func read(reference: CredentialReference, store: CredentialStore = KeychainCredentialStore()) -> String? {
        guard let record = try? store.read(reference: reference), let value = String(data: record.secret, encoding: .utf8) else {
            return nil
        }
        return value
    }
}

/// Refreshes and caches an OAuth access token from a stored refresh token.
actor OAuthTokenManager {
    private let metadata: OAuthProviderMetadata
    private let clientSecret: String?
    private let refreshReference: CredentialReference
    private let store: CredentialStore
    private var cachedToken: String?
    private var expiry: Date?

    init(metadata: OAuthProviderMetadata, clientSecret: String?, refreshReference: CredentialReference, store: CredentialStore = KeychainCredentialStore()) {
        self.metadata = metadata
        self.clientSecret = clientSecret
        self.refreshReference = refreshReference
        self.store = store
    }

    func accessToken(now: Date = Date()) async throws -> String {
        if let cachedToken, let expiry, expiry > now.addingTimeInterval(60) {
            return cachedToken
        }
        guard let refreshToken = ConnectorCredentials.read(reference: refreshReference, store: store) else {
            throw OAuthError.tokenExchangeFailed("missing refresh token")
        }

        var params = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": metadata.clientID
        ]
        if let clientSecret { params["client_secret"] = clientSecret }

        var request = URLRequest(url: metadata.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = OAuthFlow.formEncode(params).data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw OAuthError.tokenExchangeFailed(String(data: data, encoding: .utf8) ?? "refresh failed")
        }
        let tokens = try OAuthFlow.parseTokenResponse(data)
        cachedToken = tokens.accessToken
        expiry = tokens.expiresAt
        // A rotated refresh token, if present, replaces the stored one.
        if let rotated = tokens.refreshToken {
            try? ConnectorCredentials.save(rotated, reference: refreshReference, kind: .oauthRefreshToken, store: store)
        }
        return tokens.accessToken
    }
}
