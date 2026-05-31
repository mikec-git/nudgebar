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
