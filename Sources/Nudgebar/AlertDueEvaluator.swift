import NudgebarCore
import Foundation

/// Pure decision logic for which events are due to alert, extracted from
/// `EventMonitor` so it can be tested without EventKit, timers, or wall-clock time.
enum AlertDueEvaluator {
    /// IDs of events whose start time changed since they were last alerted. A moved
    /// event should alert again at its new time rather than stay suppressed by ID.
    static func rescheduledIDs(
        candidates: [AlertCandidate],
        alertedEvents: [String: Date]
    ) -> [String] {
        candidates.compactMap { event in
            guard let alertedStart = alertedEvents[event.id], alertedStart != event.startDate else {
                return nil
            }
            return event.id
        }
    }

    /// Events suppressed from alerting: already alerted, or under an active snooze.
    static func suppressedIDs(
        alertedEvents: [String: Date],
        snoozedUntil: [String: Date],
        now: Date
    ) -> Set<String> {
        let activeSnoozes = snoozedUntil.filter { $0.value > now }.keys
        return Set(alertedEvents.keys).union(activeSnoozes)
    }

    /// Timed (non-all-day) events whose start falls within their lead window now,
    /// sorted by soonest start. `leadMinutes` resolves the per-event lead.
    static func timedDue(
        candidates: [AlertCandidate],
        now: Date,
        suppressed: Set<String>,
        leadMinutes: (AlertCandidate) -> Int
    ) -> [AlertCandidate] {
        candidates
            .filter { event in
                guard event.isAlertable, !suppressed.contains(event.id) else { return false }
                let lead = TimeInterval(max(0, leadMinutes(event)) * 60)
                return event.startDate >= now && event.startDate <= now.addingTimeInterval(lead)
            }
            .sorted { $0.startDate < $1.startDate }
    }

    /// All-day events whose fixed fire time has arrived and that are still ongoing.
    static func allDayDue(
        candidates: [AlertCandidate],
        now: Date,
        suppressed: Set<String>,
        hour: Int,
        minute: Int,
        dayOffset: Int,
        calendar: Calendar = .current
    ) -> [AlertCandidate] {
        candidates.filter { event in
            guard event.isAllDay, !suppressed.contains(event.id), event.endDate > now else {
                return false
            }
            let fire = AllDayAlertSchedule.fireDate(
                for: event,
                hour: hour,
                minute: minute,
                dayOffset: dayOffset,
                calendar: calendar
            )
            return now >= fire
        }
    }
}
