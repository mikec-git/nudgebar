import NudgebarCore
import Combine
import Foundation

@MainActor
final class AlertPreferences: ObservableObject {
    static let allowedLeadMinutes = [0, 1, 2, 5, 10, 15, 30]
    static let snoozePresetMinutes: [Int] = [1, 5, 10]
    static let defaultSnoozeMinutes: Int = 5
    static let autoDismissRangeSeconds: ClosedRange<Int> = 5...300
    static let autoDismissNeverSentinel: Int = 0
    static let maxTitleChars: Int = 24
    static let defaultSoundName: String = "Glass"

    private enum Key {
        static let fullScreenAlerts = "fullScreenAlerts"
        static let leadMinutes = "leadMinutes"
        static let pollSeconds = "pollSeconds"
        static let ignoredCalendarIDs = "ignoredCalendarIDs"
        static let soundName = "soundName"
        static let autoDismissSeconds = "autoDismissSeconds"
        static let respectFocus = "respectFocus"
        static let notificationFallback = "notificationFallbackEnabled"
        static let calendarRules = "calendarRules"
        static let shortcuts = "shortcuts"
    }

    private let defaults: UserDefaults

    @Published var fullScreenAlerts: Bool { didSet { defaults.set(fullScreenAlerts, forKey: Key.fullScreenAlerts) } }
    @Published var leadMinutes: Int { didSet { defaults.set(leadMinutes, forKey: Key.leadMinutes) } }
    @Published var pollSeconds: Int { didSet { defaults.set(pollSeconds, forKey: Key.pollSeconds) } }
    @Published var soundName: String { didSet { defaults.set(soundName, forKey: Key.soundName) } }
    @Published var autoDismissSeconds: Int { didSet { defaults.set(autoDismissSeconds, forKey: Key.autoDismissSeconds) } }
    @Published var respectFocus: Bool { didSet { defaults.set(respectFocus, forKey: Key.respectFocus) } }
    @Published var notificationFallbackEnabled: Bool { didSet { defaults.set(notificationFallbackEnabled, forKey: Key.notificationFallback) } }

    @Published private var ignoredCalendarIDs: Set<String> {
        didSet { defaults.set(Array(ignoredCalendarIDs), forKey: Key.ignoredCalendarIDs) }
    }
    @Published private(set) var calendarRules: [String: CalendarAlertRule] {
        didSet { persistCodable(calendarRules, forKey: Key.calendarRules) }
    }
    @Published private(set) var shortcuts: [String: ShortcutBinding] {
        didSet { persistCodable(shortcuts, forKey: Key.shortcuts) }
    }

    var leadTime: TimeInterval {
        TimeInterval(max(0, leadMinutes) * 60)
    }

    var autoDismissEnabled: Bool {
        autoDismissSeconds != Self.autoDismissNeverSentinel
    }

    /// Largest lead time across the global default and all per-calendar overrides,
    /// used to size the monitor's look-ahead query window.
    var maxEffectiveLeadSeconds: TimeInterval {
        let overrides = calendarRules.values.compactMap(\.leadMinutesOverride)
        let maxMinutes = ([leadMinutes] + overrides).max() ?? leadMinutes
        return TimeInterval(max(0, maxMinutes) * 60)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.fullScreenAlerts = defaults.object(forKey: Key.fullScreenAlerts) as? Bool ?? true
        self.leadMinutes = defaults.object(forKey: Key.leadMinutes) as? Int ?? 5
        self.pollSeconds = defaults.object(forKey: Key.pollSeconds) as? Int ?? 30
        self.ignoredCalendarIDs = Set(defaults.stringArray(forKey: Key.ignoredCalendarIDs) ?? [])
        self.soundName = defaults.string(forKey: Key.soundName) ?? Self.defaultSoundName
        self.autoDismissSeconds = defaults.object(forKey: Key.autoDismissSeconds) as? Int ?? 30
        self.respectFocus = defaults.object(forKey: Key.respectFocus) as? Bool ?? false
        self.notificationFallbackEnabled = defaults.object(forKey: Key.notificationFallback) as? Bool ?? true
        self.calendarRules = Self.loadCodable([String: CalendarAlertRule].self, forKey: Key.calendarRules, defaults: defaults) ?? [:]
        self.shortcuts = Self.loadCodable([String: ShortcutBinding].self, forKey: Key.shortcuts, defaults: defaults) ?? [:]
    }

    func isCalendarEnabled(id: String) -> Bool {
        !ignoredCalendarIDs.contains(id)
    }

    func setCalendar(id: String, enabled: Bool) {
        if enabled {
            ignoredCalendarIDs.remove(id)
        } else {
            ignoredCalendarIDs.insert(id)
        }
    }

    func enabledCalendarIDs(from calendars: [CalendarSource]) -> Set<String> {
        Set(calendars.map(\.id).filter(isCalendarEnabled))
    }

    func rule(for calendarID: String) -> CalendarAlertRule? {
        calendarRules[calendarID]
    }

    func setRule(_ rule: CalendarAlertRule?, for calendarID: String) {
        if let rule, !rule.isEmpty {
            calendarRules[calendarID] = rule
        } else {
            calendarRules.removeValue(forKey: calendarID)
        }
    }

    func effectiveSettings(for event: AlertCandidate) -> EffectiveAlertSettings {
        AlertRuleResolver.resolve(
            rule: calendarRules[event.sourceID],
            globalLeadMinutes: leadMinutes,
            globalSound: soundName
        )
    }

    func shortcut(for action: ShortcutAction) -> ShortcutBinding? {
        shortcuts[action.rawValue]
    }

    func setShortcut(_ binding: ShortcutBinding?, for action: ShortcutAction) {
        if let binding {
            shortcuts[action.rawValue] = binding
        } else {
            shortcuts.removeValue(forKey: action.rawValue)
        }
    }

    private func persistCodable<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private static func loadCodable<T: Decodable>(_ type: T.Type, forKey key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }
}
