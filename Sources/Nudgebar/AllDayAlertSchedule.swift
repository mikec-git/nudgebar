import NudgebarCore
import Foundation

/// Computes when an all-day event should alert: `dayOffset` days before the event's
/// day, at a fixed clock time. Pure and unit-tested.
enum AllDayAlertSchedule {
    static func fireDate(
        for event: AlertCandidate,
        hour: Int,
        minute: Int,
        dayOffset: Int,
        calendar: Calendar = .current
    ) -> Date {
        let eventDay = calendar.startOfDay(for: event.startDate)
        let day = calendar.date(byAdding: .day, value: -max(0, dayOffset), to: eventDay) ?? eventDay
        return calendar.date(
            bySettingHour: max(0, min(23, hour)),
            minute: max(0, min(59, minute)),
            second: 0,
            of: day
        ) ?? day
    }
}
