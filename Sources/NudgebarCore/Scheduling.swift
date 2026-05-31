import Foundation

public struct OneShotAlertSchedule: Codable, Equatable, Sendable {
    public let groupID: String
    public let fireDate: Date

    public init(groupID: String, fireDate: Date) {
        self.groupID = groupID
        self.fireDate = fireDate
    }
}

public enum OneShotAlertScheduler {
    public static func nextSchedule(
        from plan: AlertPlan,
        states: [String: AlertInteractionState],
        now: Date
    ) -> OneShotAlertSchedule? {
        for group in plan.groups {
            if let state = states[group.id], state.status == .snoozed, let snoozedUntil = state.snoozedUntil {
                if snoozedUntil >= now {
                    return OneShotAlertSchedule(groupID: group.id, fireDate: snoozedUntil)
                }
            }

            if group.primaryOccurrence.startDate >= now {
                return OneShotAlertSchedule(groupID: group.id, fireDate: group.primaryOccurrence.startDate)
            }
        }

        return nil
    }
}

public enum LifecycleReconciliationReason: String, Codable, Equatable, Sendable {
    case launch
    case wake
    case networkReturned
    case timeZoneChanged
    case displayConfigurationChanged
    case eventKitChanged
    case cacheUpdated
    case settingsUpdated
    case providerUpdated
}

public struct LifecycleReconciliationResult: Codable, Equatable, Sendable {
    public let reason: LifecycleReconciliationReason
    public let plan: AlertPlan
    public let nextSchedule: OneShotAlertSchedule?
    public let needsProviderRefresh: Bool
    public let shouldRefreshPresentationDisplays: Bool

    public init(
        reason: LifecycleReconciliationReason,
        plan: AlertPlan,
        nextSchedule: OneShotAlertSchedule?,
        needsProviderRefresh: Bool,
        shouldRefreshPresentationDisplays: Bool
    ) {
        self.reason = reason
        self.plan = plan
        self.nextSchedule = nextSchedule
        self.needsProviderRefresh = needsProviderRefresh
        self.shouldRefreshPresentationDisplays = shouldRefreshPresentationDisplays
    }
}

public enum AlertLifecycleReconciler {
    public static func reconcile(
        reason: LifecycleReconciliationReason,
        occurrences: [AlertOccurrence],
        states: [String: AlertInteractionState],
        preferences: AlertPreferencesSnapshot,
        now: Date
    ) -> LifecycleReconciliationResult {
        let plan = AlertPlanner.plan(
            occurrences: occurrences,
            states: states,
            preferences: preferences,
            now: now
        )

        return LifecycleReconciliationResult(
            reason: reason,
            plan: plan,
            nextSchedule: OneShotAlertScheduler.nextSchedule(from: plan, states: states, now: now),
            needsProviderRefresh: [.launch, .wake, .networkReturned, .eventKitChanged].contains(reason),
            shouldRefreshPresentationDisplays: reason == .displayConfigurationChanged
        )
    }
}
