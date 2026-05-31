import NudgebarCore
import Foundation

public struct AlertSettings: Codable, Equatable, Sendable {
    public let leadMinutes: Int
    public let fullScreenAlerts: Bool
    public let enabledProviderIDs: Set<ProviderID>
    public let selectedSourceIDs: Set<String>

    public init(
        leadMinutes: Int = 5,
        fullScreenAlerts: Bool = true,
        enabledProviderIDs: Set<ProviderID> = Set(ProviderID.allCases),
        selectedSourceIDs: Set<String> = []
    ) {
        self.leadMinutes = leadMinutes
        self.fullScreenAlerts = fullScreenAlerts
        self.enabledProviderIDs = enabledProviderIDs
        self.selectedSourceIDs = selectedSourceIDs
    }

    public var snapshot: AlertPreferencesSnapshot {
        AlertPreferencesSnapshot(
            leadTime: TimeInterval(max(0, leadMinutes) * 60),
            fullScreenAlerts: fullScreenAlerts,
            enabledProviderIDs: enabledProviderIDs,
            selectedSourceIDs: selectedSourceIDs
        )
    }
}

public protocol SettingsPersistence {
    func loadSettings() throws -> AlertSettings
    func saveSettings(_ settings: AlertSettings) throws
}

public protocol AccountMetadataPersistence {
    func loadAccounts() throws -> [ConnectedAccount]
    func saveAccounts(_ accounts: [ConnectedAccount]) throws
}

public protocol SourceSelectionPersistence {
    func loadSources() throws -> [CalendarSource]
    func saveSources(_ sources: [CalendarSource]) throws
}

public protocol SyncCursorPersistence {
    func loadSyncCursors() throws -> [SyncCursor]
    func saveSyncCursors(_ cursors: [SyncCursor]) throws
}

public protocol AlertStatePersistence {
    func loadAlertStates() throws -> [String: AlertInteractionState]
    func saveAlertStates(_ states: [String: AlertInteractionState]) throws
}

public protocol EventCachePersistence {
    func loadCachedOccurrences(now: Date) throws -> [AlertOccurrence]
    func saveCachedOccurrences(_ occurrences: [AlertOccurrence], validUntil: Date) throws
    func invalidateCachedOccurrences() throws
}

public typealias NudgebarPersistenceStore = SettingsPersistence & AccountMetadataPersistence & SourceSelectionPersistence & SyncCursorPersistence & AlertStatePersistence & EventCachePersistence
