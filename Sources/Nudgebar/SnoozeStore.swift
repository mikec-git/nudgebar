import Combine
import Foundation

@MainActor
final class SnoozeStore: ObservableObject {
    @Published private(set) var snoozedUntil: [String: Date] = [:]

    func snooze(eventID: String, minutes: Int, now: Date = .now) {
        let interval = TimeInterval(max(0, minutes) * 60)
        snoozedUntil[eventID] = now.addingTimeInterval(interval)
    }

    func clear(eventID: String) {
        snoozedUntil.removeValue(forKey: eventID)
    }

    func clearExpired(now: Date = .now) {
        snoozedUntil = snoozedUntil.filter { _, until in
            until > now
        }
    }

    func isSnoozed(eventID: String, now: Date = .now) -> Bool {
        guard let until = snoozedUntil[eventID] else {
            return false
        }
        return until > now
    }

    func snoozedUntil(eventID: String) -> Date? {
        snoozedUntil[eventID]
    }
}
