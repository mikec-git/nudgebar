import Foundation

/// Per-calendar overrides. Absent fields fall back to the global defaults.
struct CalendarAlertRule: Codable, Equatable, Sendable {
    var leadMinutesOverride: Int?
    var soundOverride: String?

    var isEmpty: Bool {
        leadMinutesOverride == nil && soundOverride == nil
    }
}

struct EffectiveAlertSettings: Equatable, Sendable {
    let leadMinutes: Int
    let soundName: String
}

/// Pure resolution of per-calendar overrides against global defaults.
enum AlertRuleResolver {
    static func resolve(
        rule: CalendarAlertRule?,
        globalLeadMinutes: Int,
        globalSound: String
    ) -> EffectiveAlertSettings {
        EffectiveAlertSettings(
            leadMinutes: rule?.leadMinutesOverride ?? globalLeadMinutes,
            soundName: rule?.soundOverride ?? globalSound
        )
    }
}

enum AlertDeliveryDecision: Equatable, Sendable {
    case fullScreen
    case notification
    case suppressed
}

/// Pure delivery decision. Focus state is supplied by the caller (no public macOS
/// Focus API), so the "respect Focus" toggle is the reliable control.
enum AlertDeliveryDecider {
    static func decide(
        fullScreenEnabled: Bool,
        respectFocus: Bool,
        focusActive: Bool,
        notificationFallback: Bool
    ) -> AlertDeliveryDecision {
        if respectFocus && focusActive {
            return notificationFallback ? .notification : .suppressed
        }
        if fullScreenEnabled {
            return .fullScreen
        }
        return notificationFallback ? .notification : .suppressed
    }
}
