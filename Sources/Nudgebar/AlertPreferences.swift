import NudgebarCore
import Combine
import Foundation

@MainActor
final class AlertPreferences: ObservableObject {
    static let allowedLeadMinutes = [0, 1, 2, 5, 10, 15, 30]
    static let snoozePresetMinutes: [Int] = [1, 5, 10]
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
    }

    private let defaults: UserDefaults

    @Published var fullScreenAlerts: Bool {
        didSet {
            defaults.set(fullScreenAlerts, forKey: Key.fullScreenAlerts)
        }
    }

    @Published var leadMinutes: Int {
        didSet {
            defaults.set(leadMinutes, forKey: Key.leadMinutes)
        }
    }

    @Published var pollSeconds: Int {
        didSet {
            defaults.set(pollSeconds, forKey: Key.pollSeconds)
        }
    }

    @Published var soundName: String {
        didSet {
            defaults.set(soundName, forKey: Key.soundName)
        }
    }

    @Published var autoDismissSeconds: Int {
        didSet {
            defaults.set(autoDismissSeconds, forKey: Key.autoDismissSeconds)
        }
    }

    @Published private var ignoredCalendarIDs: Set<String> {
        didSet {
            defaults.set(Array(ignoredCalendarIDs), forKey: Key.ignoredCalendarIDs)
        }
    }

    var leadTime: TimeInterval {
        TimeInterval(max(0, leadMinutes) * 60)
    }

    var autoDismissEnabled: Bool {
        autoDismissSeconds != Self.autoDismissNeverSentinel
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.fullScreenAlerts = defaults.object(forKey: Key.fullScreenAlerts) as? Bool ?? true
        self.leadMinutes = defaults.object(forKey: Key.leadMinutes) as? Int ?? 5
        self.pollSeconds = defaults.object(forKey: Key.pollSeconds) as? Int ?? 30
        self.ignoredCalendarIDs = Set(defaults.stringArray(forKey: Key.ignoredCalendarIDs) ?? [])
        self.soundName = defaults.string(forKey: Key.soundName) ?? Self.defaultSoundName
        self.autoDismissSeconds = defaults.object(forKey: Key.autoDismissSeconds) as? Int ?? 30
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
}
