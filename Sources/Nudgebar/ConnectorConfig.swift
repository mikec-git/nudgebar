import NudgebarCore
import Foundation

/// OAuth client credentials supplied by the user, loaded from a file OUTSIDE the
/// repo so secrets are never committed:
/// ~/Library/Application Support/Nudgebar/connectors.json
struct ConnectorClientConfig: Codable, Equatable {
    var googleClientID: String?
    var googleClientSecret: String?
    var microsoftClientID: String?
    var calendlyClientID: String?
    var calendlyClientSecret: String?
    var calComAPIKey: String?
    var acuityClientID: String?
    var acuityClientSecret: String?

    func oauthClientID(for providerID: ProviderID) -> String? {
        switch providerID {
        case .googleCalendar: return googleClientID
        case .microsoftGraph: return microsoftClientID
        case .calendly: return calendlyClientID
        case .eventKit, .calDAV, .calCom, .acuity: return nil
        }
    }

    func oauthClientSecret(for providerID: ProviderID) -> String? {
        switch providerID {
        case .googleCalendar: return googleClientSecret
        case .calendly: return calendlyClientSecret
        case .acuity: return acuityClientSecret
        case .eventKit, .microsoftGraph, .calDAV, .calCom: return nil
        }
    }
}

/// A field collected by the credential-entry sheet for non-OAuth connectors.
struct ConnectorCredentialField: Identifiable, Equatable {
    let key: String
    let label: String
    let isSecret: Bool
    var id: String { key }
}

enum ConnectorConfig {
    /// Must match the CFBundleURLSchemes entry in Info.plist.
    static let redirectScheme = "com.local.nudgebar"
    static var redirectURI: URL { URL(string: "\(redirectScheme)://oauth")! }

    static var fileURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nudgebar", isDirectory: true)
        return base.appendingPathComponent("connectors.json")
    }

    static func load() -> ConnectorClientConfig {
        guard let data = try? Data(contentsOf: fileURL),
              let config = try? JSONDecoder().decode(ConnectorClientConfig.self, from: data) else {
            return ConnectorClientConfig()
        }
        return config
    }

    static func save(_ config: ConnectorClientConfig) {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(config) {
            try? data.write(to: fileURL)
        }
    }

    /// The OAuth redirect URI + callback scheme for a provider. Google only accepts
    /// its reverse-DNS scheme (derived from the client ID); others use the app scheme.
    static func redirect(for providerID: ProviderID, clientID: String) -> (uri: URL, scheme: String) {
        let suffix = ".apps.googleusercontent.com"
        if providerID == .googleCalendar, clientID.hasSuffix(suffix) {
            let scheme = "com.googleusercontent.apps.\(clientID.replacingOccurrences(of: suffix, with: ""))"
            return (URL(string: "\(scheme):/oauth")!, scheme)
        }
        return (redirectURI, redirectScheme)
    }

    /// Human-facing redirect URI to register in the provider's console.
    static func redirectHint(for providerID: ProviderID) -> String {
        providerID == .googleCalendar
            ? "Auto-derived — create an \"iOS\" OAuth client (any bundle ID); no redirect entry needed."
            : redirectURI.absoluteString
    }

    /// True when the provider has the credentials it needs to connect.
    static func isConfigured(_ providerID: ProviderID, config: ConnectorClientConfig = load()) -> Bool {
        switch providerID {
        case .eventKit, .calDAV:
            return true // EventKit needs no config; CalDAV credentials are entered per account
        case .googleCalendar, .microsoftGraph, .calendly:
            return config.oauthClientID(for: providerID)?.isEmpty == false
        case .calCom:
            return config.calComAPIKey?.isEmpty == false
        case .acuity:
            return config.acuityClientID?.isEmpty == false
        }
    }
}
