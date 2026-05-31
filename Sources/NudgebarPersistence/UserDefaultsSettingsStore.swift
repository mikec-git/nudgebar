import NudgebarCore
import Foundation

public final class UserDefaultsSettingsStore: SettingsPersistence {
    private enum Key {
        static let leadMinutes = "leadMinutes"
        static let fullScreenAlerts = "fullScreenAlerts"
        static let enabledProviderIDs = "enabledProviderIDs"
        static let selectedSourceIDs = "selectedSourceIDs"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadSettings() throws -> AlertSettings {
        let providerIDs = defaults
            .stringArray(forKey: Key.enabledProviderIDs)?
            .compactMap(ProviderID.init(rawValue:))

        return AlertSettings(
            leadMinutes: defaults.object(forKey: Key.leadMinutes) as? Int ?? 5,
            fullScreenAlerts: defaults.object(forKey: Key.fullScreenAlerts) as? Bool ?? true,
            enabledProviderIDs: Set(providerIDs ?? ProviderID.allCases),
            selectedSourceIDs: Set(defaults.stringArray(forKey: Key.selectedSourceIDs) ?? [])
        )
    }

    public func saveSettings(_ settings: AlertSettings) throws {
        try save(settings.leadMinutes, key: Key.leadMinutes)
        try save(settings.fullScreenAlerts, key: Key.fullScreenAlerts)
        try save(settings.enabledProviderIDs.map(\.rawValue).sorted(), key: Key.enabledProviderIDs)
        try save(Array(settings.selectedSourceIDs).sorted(), key: Key.selectedSourceIDs)
    }

    private func save(_ value: Any, key: String) throws {
        try SensitiveDataGuard.validateNonSensitive(
            key: key,
            valueDescription: String(describing: value)
        )
        defaults.set(value, forKey: key)
    }
}
