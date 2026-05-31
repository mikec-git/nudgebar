import NudgebarAuth
import NudgebarCore
import AppKit
import AuthenticationServices
import Foundation
import Security

struct OAuthTokens: Equatable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
}

enum OAuthError: Error, Equatable {
    case cancelled
    case stateMismatch
    case missingCode
    case tokenExchangeFailed(String)
}

/// Authorization-code + PKCE flow. The URL-building, callback-parsing, and
/// token-response decoding are pure and unit-tested; the browser session and HTTP
/// exchange are the live legs (need real OAuth credentials).
@MainActor
final class OAuthFlow: NSObject {
    private var session: ASWebAuthenticationSession?

    func authorize(
        metadata: OAuthProviderMetadata,
        clientSecret: String?,
        extraAuthParameters: [String: String] = [:]
    ) async throws -> OAuthTokens {
        let verifier = Self.randomToken(64)
        let pkce = PKCEChallenge(verifier: verifier)
        let state = Self.randomToken(24)
        let authURL = Self.authorizationURL(metadata: metadata, challenge: pkce.challenge, state: state, extra: extraAuthParameters)
        let callback = try await presentSession(url: authURL)
        let code = try Self.parseCallback(callback, expectedState: state)
        return try await exchangeCode(code, verifier: verifier, metadata: metadata, clientSecret: clientSecret)
    }

    // MARK: - Pure helpers

    nonisolated static func authorizationURL(
        metadata: OAuthProviderMetadata,
        challenge: String,
        state: String,
        extra: [String: String] = [:]
    ) -> URL {
        var components = URLComponents(url: metadata.authorizationEndpoint, resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "client_id", value: metadata.clientID),
            URLQueryItem(name: "redirect_uri", value: metadata.redirectURI.absoluteString),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: metadata.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state)
        ]
        if metadata.usesPKCE {
            items.append(URLQueryItem(name: "code_challenge", value: challenge))
            items.append(URLQueryItem(name: "code_challenge_method", value: "S256"))
        }
        for (key, value) in extra.sorted(by: { $0.key < $1.key }) {
            items.append(URLQueryItem(name: key, value: value))
        }
        components.queryItems = items
        return components.url!
    }

    nonisolated static func parseCallback(_ url: URL, expectedState: String) throws -> String {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
            throw OAuthError.missingCode
        }
        if let error = items.first(where: { $0.name == "error" })?.value {
            throw OAuthError.tokenExchangeFailed(error)
        }
        guard items.first(where: { $0.name == "state" })?.value == expectedState else {
            throw OAuthError.stateMismatch
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw OAuthError.missingCode
        }
        return code
    }

    nonisolated static func parseTokenResponse(_ data: Data) throws -> OAuthTokens {
        struct Response: Decodable {
            let access_token: String
            let refresh_token: String?
            let expires_in: Double?
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return OAuthTokens(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token,
            expiresAt: decoded.expires_in.map { Date().addingTimeInterval($0) }
        )
    }

    nonisolated static func randomToken(_ bytes: Int) -> String {
        var data = Data(count: bytes)
        _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, bytes, $0.baseAddress!) }
        return data.base64URLEncoded()
    }

    nonisolated static func formEncode(_ params: [String: String]) -> String {
        params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .formValueAllowed) ?? "")" }
            .joined(separator: "&")
    }

    // MARK: - Live legs

    private func presentSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: ConnectorConfig.redirectScheme) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: OAuthError.cancelled)
                } else {
                    continuation.resume(throwing: error ?? OAuthError.cancelled)
                }
            }
            session.presentationContextProvider = self
            session.start()
            self.session = session
        }
    }

    private func exchangeCode(
        _ code: String,
        verifier: String,
        metadata: OAuthProviderMetadata,
        clientSecret: String?
    ) async throws -> OAuthTokens {
        var request = URLRequest(url: metadata.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var params = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": metadata.redirectURI.absoluteString,
            "client_id": metadata.clientID,
            "code_verifier": verifier
        ]
        if let clientSecret { params["client_secret"] = clientSecret }
        request.httpBody = Self.formEncode(params).data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw OAuthError.tokenExchangeFailed(String(data: data, encoding: .utf8) ?? "token exchange failed")
        }
        return try Self.parseTokenResponse(data)
    }
}

extension OAuthFlow: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApp.windows.first { $0.isVisible } ?? NSApp.windows.first ?? NSWindow()
    }
}

extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

extension CharacterSet {
    static let formValueAllowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}
