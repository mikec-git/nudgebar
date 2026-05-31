import NudgebarCore
import Foundation

enum UpcomingEventsList {
    static let maxEntries: Int = 25

    /// End-of-tomorrow boundary used as the upcoming-events window upper bound.
    static func endOfTomorrow(from now: Date, calendar: Calendar = .current) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        guard let dayAfterTomorrowStart = calendar.date(byAdding: .day, value: 2, to: startOfToday) else {
            return now.addingTimeInterval(48 * 60 * 60)
        }
        return dayAfterTomorrowStart.addingTimeInterval(-1)
    }

    /// Filter to upcoming events from `now` through end of tomorrow, sorted ascending by start, capped at 25.
    static func filter(
        _ events: [AlertCandidate],
        now: Date,
        calendar: Calendar = .current
    ) -> [AlertCandidate] {
        let windowEnd = endOfTomorrow(from: now, calendar: calendar)
        let filtered = events
            .filter { event in
                event.startDate >= now && event.startDate <= windowEnd
            }
            .sorted { $0.startDate < $1.startDate }
        return Array(filtered.prefix(maxEntries))
    }

    enum DayGroup: String {
        case today
        case tomorrow
    }

    struct GroupedEvent: Equatable, Identifiable {
        let event: AlertCandidate
        let group: DayGroup

        var id: String {
            event.id
        }
    }

    static func group(
        _ events: [AlertCandidate],
        now: Date,
        calendar: Calendar = .current
    ) -> [GroupedEvent] {
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return events.map { GroupedEvent(event: $0, group: .today) }
        }
        return events.map { event in
            let group: DayGroup = event.startDate < startOfTomorrow ? .today : .tomorrow
            return GroupedEvent(event: event, group: group)
        }
    }

    /// Returns true when more than `maxEntries` events fell within the window.
    static func wasTruncated(
        _ events: [AlertCandidate],
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        let windowEnd = endOfTomorrow(from: now, calendar: calendar)
        let inWindow = events.filter { event in
            event.startDate >= now && event.startDate <= windowEnd
        }
        return inWindow.count > maxEntries
    }
}
