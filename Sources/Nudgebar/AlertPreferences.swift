import NudgebarCore
import Combine
import Foundation

@MainActor
final class AlertPreferences: ObservableObject {
    static let allowedLeadMinutes = [0, 1, 2, 5, 10, 15, 30]

    private enum Key {
        static let fullScreenAlerts = "fullScreenAlerts"
        static let leadMinutes = "leadMinutes"
        static let pollSeconds = "pollSeconds"
        static let ignoredCalendarIDs = "ignoredCalendarIDs"
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

    @Published private var ignoredCalendarIDs: Set<String> {
        didSet {
            defaults.set(Array(ignoredCalendarIDs), forKey: Key.ignoredCalendarIDs)
        }
    }

    var leadTime: TimeInterval {
        TimeInterval(max(0, leadMinutes) * 60)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.fullScreenAlerts = defaults.object(forKey: Key.fullScreenAlerts) as? Bool ?? true
        self.leadMinutes = defaults.object(forKey: Key.leadMinutes) as? Int ?? 5
        self.pollSeconds = defaults.object(forKey: Key.pollSeconds) as? Int ?? 30
        self.ignoredCalendarIDs = Set(defaults.stringArray(forKey: Key.ignoredCalendarIDs) ?? [])
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
