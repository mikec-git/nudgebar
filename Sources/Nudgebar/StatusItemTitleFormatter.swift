import NudgebarCore
import Foundation

enum StatusItemProximity: Equatable {
    case none
    case urgent
    case warning
    case `default`
}

struct StatusItemTitle: Equatable {
    let text: String
    let proximity: StatusItemProximity

    static let empty = StatusItemTitle(text: "", proximity: .none)
}

enum StatusItemTitleFormatter {
    static let maxTitleChars: Int = AlertPreferences.maxTitleChars
    static let urgentThresholdSeconds: TimeInterval = 5 * 60
    static let warningThresholdSeconds: TimeInterval = 15 * 60
    static let imminentThresholdSeconds: TimeInterval = 30
    static let liveCadenceThresholdSeconds: TimeInterval = 60 * 60

    /// Returns title text + proximity bucket for the given upcoming event.
    /// Returns `.empty` (icon-only) when `event == nil` or when start has already passed.
    static func title(
        for event: AlertCandidate?,
        now: Date
    ) -> StatusItemTitle {
        guard let event else {
            return .empty
        }

        let secondsUntilStart = event.startDate.timeIntervalSince(now)

        guard secondsUntilStart >= 0 else {
            return .empty
        }

        let proximity = proximityBucket(secondsUntilStart: secondsUntilStart)
        let truncatedTitle = truncate(event.title, to: maxTitleChars)
        let countdown = countdownText(secondsUntilStart: secondsUntilStart)
        let text = "\(truncatedTitle) · \(countdown)"

        return StatusItemTitle(text: text, proximity: proximity)
    }

    static func proximityBucket(secondsUntilStart: TimeInterval) -> StatusItemProximity {
        if secondsUntilStart <= urgentThresholdSeconds {
            return .urgent
        }
        if secondsUntilStart <= warningThresholdSeconds {
            return .warning
        }
        return .default
    }

    static func countdownText(secondsUntilStart: TimeInterval) -> String {
        if secondsUntilStart <= 0 {
            return "now"
        }
        if secondsUntilStart < imminentThresholdSeconds {
            return "starts in <30s"
        }
        let minutes = Int(ceil(secondsUntilStart / 60.0))
        if minutes < 60 {
            return "\(minutes)m"
        }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    /// Middle-truncate a string to at most `limit` characters, using a single ellipsis.
    static func truncate(_ value: String, to limit: Int) -> String {
        guard limit > 0 else {
            return ""
        }
        let count = value.count
        if count <= limit {
            return value
        }
        if limit == 1 {
            return "…"
        }
        // Reserve one character for the ellipsis; split the remaining budget between head/tail.
        let budget = limit - 1
        let headCount = (budget + 1) / 2
        let tailCount = budget - headCount
        let head = value.prefix(headCount)
        let tail = tailCount > 0 ? value.suffix(tailCount) : ""
        return "\(head)…\(tail)"
    }

    /// Tick cadence for the status item title.
    static func tickInterval(secondsUntilStart: TimeInterval?) -> TimeInterval {
        guard let secondsUntilStart, secondsUntilStart >= 0 else {
            return 60
        }
        return secondsUntilStart <= liveCadenceThresholdSeconds ? 1 : 60
    }
}
