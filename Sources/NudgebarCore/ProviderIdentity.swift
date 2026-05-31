import Foundation

public enum ProviderID: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case eventKit = "eventkit"
    case googleCalendar = "google_calendar"
    case microsoftGraph = "microsoft_graph"
    case calDAV = "caldav"
    case calendly = "calendly"
    case calCom = "cal_com"
    case acuity = "acuity"

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .eventKit:
            return "macOS Calendar"
        case .googleCalendar:
            return "Google Calendar"
        case .microsoftGraph:
            return "Microsoft Outlook / Exchange"
        case .calDAV:
            return "CalDAV"
        case .calendly:
            return "Calendly"
        case .calCom:
            return "Cal.com"
        case .acuity:
            return "Acuity Scheduling"
        }
    }

    public var presentationPriority: Int {
        switch self {
        case .googleCalendar, .microsoftGraph, .calDAV:
            return 100
        case .calendly, .calCom, .acuity:
            return 90
        case .eventKit:
            return 10
        }
    }
}

public enum ProviderCapability: String, CaseIterable, Codable, Hashable, Sendable {
    case accountDiscovery
    case sourceDiscovery
    case readEvents
    case recurringEvents
    case cancellationHandling
    case deltaSync
    case pollingSync
    case localChangeNotifications
    case schedulingBookings
}

public enum ProviderAuthMode: String, Codable, Hashable, Sendable {
    case macOSPrivacy
    case oauthPKCE
    case calDAVCredentials
    case apiKey
    case basicAuth
}

public struct ProviderDescriptor: Codable, Equatable, Identifiable, Sendable {
    public let id: ProviderID
    public let authMode: ProviderAuthMode
    public let capabilities: Set<ProviderCapability>
    public let minimumScopes: [String]
    public let notes: String

    public init(
        id: ProviderID,
        authMode: ProviderAuthMode,
        capabilities: Set<ProviderCapability>,
        minimumScopes: [String] = [],
        notes: String
    ) {
        self.id = id
        self.authMode = authMode
        self.capabilities = capabilities
        self.minimumScopes = minimumScopes
        self.notes = notes
    }

    public var displayName: String {
        id.displayName
    }
}

public struct CredentialReference: Codable, Equatable, Hashable, Sendable {
    public let service: String
    public let account: String
    public let kind: String

    public init(service: String, account: String, kind: String) {
        self.service = service
        self.account = account
        self.kind = kind
    }
}

public struct ProviderIdentity: Codable, Equatable, Hashable, Sendable {
    public let providerID: ProviderID
    public let accountID: String
    public let sourceID: String
    public let externalID: String

    public init(
        providerID: ProviderID,
        accountID: String,
        sourceID: String,
        externalID: String
    ) {
        self.providerID = providerID
        self.accountID = accountID
        self.sourceID = sourceID
        self.externalID = externalID
    }
}
