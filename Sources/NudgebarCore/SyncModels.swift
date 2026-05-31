import Foundation

public enum SyncTrigger: String, Codable, Equatable, Sendable {
    case initial
    case incremental
    case poll
    case eventKitChange
    case lifecycle
}

public struct SyncCursor: Codable, Equatable, Identifiable, Sendable {
    public var id: String {
        [providerID.rawValue, accountID, sourceID].joined(separator: ":")
    }

    public let providerID: ProviderID
    public let accountID: String
    public let sourceID: String
    public let value: String
    public let updatedAt: Date
    public let metadata: [String: String]

    public init(
        providerID: ProviderID,
        accountID: String,
        sourceID: String,
        value: String,
        updatedAt: Date,
        metadata: [String: String] = [:]
    ) {
        self.providerID = providerID
        self.accountID = accountID
        self.sourceID = sourceID
        self.value = value
        self.updatedAt = updatedAt
        self.metadata = metadata
    }
}

public struct ProviderSyncRequest: Equatable, Sendable {
    public let account: ConnectedAccount
    public let sources: [CalendarSource]
    public let windowStart: Date
    public let windowEnd: Date
    public let previousCursor: SyncCursor?
    public let trigger: SyncTrigger

    public init(
        account: ConnectedAccount,
        sources: [CalendarSource],
        windowStart: Date,
        windowEnd: Date,
        previousCursor: SyncCursor? = nil,
        trigger: SyncTrigger
    ) {
        self.account = account
        self.sources = sources
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.previousCursor = previousCursor
        self.trigger = trigger
    }
}

public struct ProviderSyncResult: Equatable, Sendable {
    public let occurrences: [AlertOccurrence]
    public let deletedOccurrenceIDs: Set<String>
    public let nextCursor: SyncCursor?
    public let completedAt: Date

    public init(
        occurrences: [AlertOccurrence],
        deletedOccurrenceIDs: Set<String> = [],
        nextCursor: SyncCursor? = nil,
        completedAt: Date
    ) {
        self.occurrences = occurrences
        self.deletedOccurrenceIDs = deletedOccurrenceIDs
        self.nextCursor = nextCursor
        self.completedAt = completedAt
    }
}

public enum ProviderSyncError: Error, Equatable {
    case credentialsUnavailable(ProviderID)
    case sourceUnavailable(String)
    case unsupported(String)
    case invalidResponse(String)
    case transport(String)
}
