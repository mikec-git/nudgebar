import NudgebarCore
import Foundation

/// OAuth client credentials for the direct connectors that need them (Calendly),
/// loaded from a file OUTSIDE the repo so secrets are never committed:
/// ~/Library/Application Support/Nudgebar/connectors.json
struct ConnectorClientConfig: Codable, Equatable {
    var calendlyClientID: String?
    var calendlyClientSecret: String?
    var calComAPIKey: String?
    var acuityClientID: String?
    var acuityClientSecret: String?

    func oauthClientID(for providerID: ProviderID) -> String? {
        switch providerID {
        case .calendly: return calendlyClientID
        case .eventKit, .googleCalendar, .microsoftGraph, .calDAV, .calCom, .acuity: return nil
        }
    }

    func oauthClientSecret(for providerID: ProviderID) -> String? {
        switch providerID {
        case .calendly: return calendlyClientSecret
        case .acuity: return acuityClientSecret
        case .eventKit, .googleCalendar, .microsoftGraph, .calDAV, .calCom: return nil
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

    /// Publisher-registered OAuth client IDs bundled with the app so users can
    /// connect by just logging in. Client IDs are public and safe to ship.
    enum Bundled {
        static let calendlyClientID: String? = nil
    }

    static func load() -> ConnectorClientConfig {
        var config = ConnectorClientConfig()
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(ConnectorClientConfig.self, from: data) {
            config = decoded
        }
        if config.calendlyClientID?.isEmpty != false { config.calendlyClientID = Bundled.calendlyClientID }
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

    static func redirect(for providerID: ProviderID, clientID: String) -> (uri: URL, scheme: String) {
        (redirectURI, redirectScheme)
    }

    static func redirectHint(for providerID: ProviderID) -> String {
        redirectURI.absoluteString
    }

    static func isConfigured(_ providerID: ProviderID, config: ConnectorClientConfig = load()) -> Bool {
        switch providerID {
        case .calendly:
            return config.oauthClientID(for: .calendly)?.isEmpty == false
        case .eventKit, .googleCalendar, .microsoftGraph, .calDAV, .calCom, .acuity:
            return true
        }
    }
}
