import NudgebarCore
import Foundation

public final class JSONFilePersistenceStore: NudgebarPersistenceStore {
    private struct EventCacheEnvelope: Codable, Equatable {
        var validUntil: Date
        var occurrences: [AlertOccurrence]
    }

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let fileManager: FileManager

    public init(
        directory: URL,
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public static func applicationSupportStore(
        appName: String = "Nudgebar"
    ) throws -> JSONFilePersistenceStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent(appName, isDirectory: true)
        return JSONFilePersistenceStore(directory: directory)
    }

    public func loadSettings() throws -> AlertSettings {
        try load(AlertSettings.self, fileName: "settings.json") ?? AlertSettings()
    }

    public func saveSettings(_ settings: AlertSettings) throws {
        try save(settings, fileName: "settings.json", guardKey: "settings")
    }

    public func loadAccounts() throws -> [ConnectedAccount] {
        try load([ConnectedAccount].self, fileName: "accounts.json") ?? []
    }

    public func saveAccounts(_ accounts: [ConnectedAccount]) throws {
        try save(accounts, fileName: "accounts.json", guardKey: "accounts")
    }

    public func loadSources() throws -> [CalendarSource] {
        try load([CalendarSource].self, fileName: "sources.json") ?? []
    }

    public func saveSources(_ sources: [CalendarSource]) throws {
        try save(sources, fileName: "sources.json", guardKey: "sources")
    }

    public func loadSyncCursors() throws -> [SyncCursor] {
        try load([SyncCursor].self, fileName: "sync-cursors.json") ?? []
    }

    public func saveSyncCursors(_ cursors: [SyncCursor]) throws {
        try save(cursors, fileName: "sync-cursors.json", guardKey: "sync_cursors")
    }

    public func loadAlertStates() throws -> [String: AlertInteractionState] {
        try load([String: AlertInteractionState].self, fileName: "alert-states.json") ?? [:]
    }

    public func saveAlertStates(_ states: [String: AlertInteractionState]) throws {
        try save(states, fileName: "alert-states.json", guardKey: "alert_states")
    }

    public func loadCachedOccurrences(now: Date) throws -> [AlertOccurrence] {
        guard let envelope = try load(EventCacheEnvelope.self, fileName: "event-cache.json") else {
            return []
        }

        guard envelope.validUntil > now else {
            try invalidateCachedOccurrences()
            return []
        }

        return envelope.occurrences
    }

    public func saveCachedOccurrences(_ occurrences: [AlertOccurrence], validUntil: Date) throws {
        try save(
            EventCacheEnvelope(validUntil: validUntil, occurrences: occurrences),
            fileName: "event-cache.json",
            guardKey: "event_cache"
        )
    }

    public func invalidateCachedOccurrences() throws {
        let url = url(for: "event-cache.json")
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func load<T: Decodable>(_ type: T.Type, fileName: String) throws -> T? {
        let url = url(for: fileName)
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        return try decoder.decode(type, from: Data(contentsOf: url))
    }

    private func save<T: Encodable>(
        _ value: T,
        fileName: String,
        guardKey: String
    ) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(value)
        try SensitiveDataGuard.validateNonSensitive(
            key: guardKey,
            valueDescription: String(decoding: data, as: UTF8.self)
        )
        try data.write(to: url(for: fileName), options: [.atomic])
    }

    private func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName, isDirectory: false)
    }
}
