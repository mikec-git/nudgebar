import Foundation

public struct ConnectedAccount: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let providerID: ProviderID
    public var displayName: String
    public var username: String?
    public var credentialReference: CredentialReference?

    public init(
        id: String,
        providerID: ProviderID,
        displayName: String,
        username: String? = nil,
        credentialReference: CredentialReference? = nil
    ) {
        self.id = id
        self.providerID = providerID
        self.displayName = displayName
        self.username = username
        self.credentialReference = credentialReference
    }
}

public struct CalendarSource: Codable, Equatable, Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let sourceTitle: String
    public let providerID: ProviderID
    public let accountID: String?
    public let externalID: String

    public init(
        id: String,
        title: String,
        sourceTitle: String,
        providerID: ProviderID = .eventKit,
        accountID: String? = nil,
        externalID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceTitle = sourceTitle
        self.providerID = providerID
        self.accountID = accountID
        self.externalID = externalID ?? id
    }
}

public enum AlertOccurrenceStatus: String, Codable, Equatable, Sendable {
    case confirmed
    case tentative
    case cancelled
    case deleted
}

public struct AlertOccurrence: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let calendarTitle: String
    public let location: String?
    public let organizer: String?
    public let calendarColorHex: String?
    public let meetingURL: URL?
    public let providerID: ProviderID
    public let accountID: String?
    public let sourceID: String
    public let externalID: String
    public let timeZoneIdentifier: String?
    public let status: AlertOccurrenceStatus
    public let isAllDay: Bool
    public let lastModified: Date?
    public let sequence: Int?
    public let dedupeHints: [String]

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        calendarTitle: String,
        location: String? = nil,
        providerID: ProviderID = .eventKit,
        accountID: String? = nil,
        sourceID: String = "default",
        externalID: String? = nil,
        timeZoneIdentifier: String? = nil,
        status: AlertOccurrenceStatus = .confirmed,
        isAllDay: Bool = false,
        lastModified: Date? = nil,
        sequence: Int? = nil,
        dedupeHints: [String] = [],
        organizer: String? = nil,
        calendarColorHex: String? = nil,
        meetingURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendarTitle = calendarTitle
        self.location = location
        self.organizer = organizer
        self.calendarColorHex = calendarColorHex
        self.meetingURL = meetingURL
        self.providerID = providerID
        self.accountID = accountID
        self.sourceID = sourceID
        self.externalID = externalID ?? id
        self.timeZoneIdentifier = timeZoneIdentifier
        self.status = status
        self.isAllDay = isAllDay
        self.lastModified = lastModified
        self.sequence = sequence
        self.dedupeHints = dedupeHints
    }

    public var isAlertable: Bool {
        !isAllDay && status == .confirmed
    }

    public var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    public var identity: ProviderIdentity {
        ProviderIdentity(
            providerID: providerID,
            accountID: accountID ?? providerID.rawValue,
            sourceID: sourceID,
            externalID: externalID
        )
    }

    public static func sample(now: Date = .now) -> AlertOccurrence {
        AlertOccurrence(
            id: "sample-alert",
            title: "Design review",
            startDate: now.addingTimeInterval(5 * 60),
            endDate: now.addingTimeInterval(35 * 60),
            calendarTitle: "Work",
            location: "Conference Room A",
            organizer: "Alex Rivera",
            calendarColorHex: "#3A7BD5",
            meetingURL: URL(string: "https://zoom.us/j/1234567890")
        )
    }
}

public typealias AlertCandidate = AlertOccurrence

public struct AlertDisplayData: Codable, Equatable, Sendable {
    public let title: String
    public let subtitle: String
    public let startsAt: Date
    public let sourceTitle: String
    public let location: String?

    public init(
        title: String,
        subtitle: String,
        startsAt: Date,
        sourceTitle: String,
        location: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.startsAt = startsAt
        self.sourceTitle = sourceTitle
        self.location = location
    }
}

public struct AlertPresentationRequest: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let groupID: String
    public let occurrenceIDs: [String]
    public let displayData: AlertDisplayData
    public let dueAt: Date
    public let fullScreen: Bool

    public init(
        id: String,
        groupID: String,
        occurrenceIDs: [String],
        displayData: AlertDisplayData,
        dueAt: Date,
        fullScreen: Bool
    ) {
        self.id = id
        self.groupID = groupID
        self.occurrenceIDs = occurrenceIDs
        self.displayData = displayData
        self.dueAt = dueAt
        self.fullScreen = fullScreen
    }
}
