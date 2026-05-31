import Foundation

public enum AlertInteractionStatus: String, Codable, Equatable, Sendable {
    case pending
    case presented
    case snoozed
    case dismissed
    case expired
}

public struct AlertInteractionState: Codable, Equatable, Identifiable, Sendable {
    public var id: String {
        groupID
    }

    public let groupID: String
    public var status: AlertInteractionStatus
    public var occurrenceFingerprint: String
    public var lastPresentedAt: Date?
    public var snoozedUntil: Date?
    public var dismissedAt: Date?
    public var expiresAt: Date?
    public var updatedAt: Date

    public init(
        groupID: String,
        status: AlertInteractionStatus = .pending,
        occurrenceFingerprint: String,
        lastPresentedAt: Date? = nil,
        snoozedUntil: Date? = nil,
        dismissedAt: Date? = nil,
        expiresAt: Date? = nil,
        updatedAt: Date
    ) {
        self.groupID = groupID
        self.status = status
        self.occurrenceFingerprint = occurrenceFingerprint
        self.lastPresentedAt = lastPresentedAt
        self.snoozedUntil = snoozedUntil
        self.dismissedAt = dismissedAt
        self.expiresAt = expiresAt
        self.updatedAt = updatedAt
    }
}

public struct AlertPreferencesSnapshot: Codable, Equatable, Sendable {
    public let leadTime: TimeInterval
    public let fullScreenAlerts: Bool
    public let enabledProviderIDs: Set<ProviderID>
    public let selectedSourceIDs: Set<String>
    public let backupNotificationWindow: TimeInterval

    public init(
        leadTime: TimeInterval,
        fullScreenAlerts: Bool,
        enabledProviderIDs: Set<ProviderID> = Set(ProviderID.allCases),
        selectedSourceIDs: Set<String> = [],
        backupNotificationWindow: TimeInterval = 60 * 60
    ) {
        self.leadTime = leadTime
        self.fullScreenAlerts = fullScreenAlerts
        self.enabledProviderIDs = enabledProviderIDs
        self.selectedSourceIDs = selectedSourceIDs
        self.backupNotificationWindow = backupNotificationWindow
    }
}

public struct LocalNotificationBackupRequest: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let fireDate: Date

    public init(id: String, title: String, body: String, fireDate: Date) {
        self.id = id
        self.title = title
        self.body = body
        self.fireDate = fireDate
    }
}

public struct AlertPlan: Codable, Equatable, Sendable {
    public let groups: [AlertGroup]
    public let dueGroups: [AlertGroup]
    public let presentationRequests: [AlertPresentationRequest]
    public let backupNotificationRequests: [LocalNotificationBackupRequest]

    public init(
        groups: [AlertGroup],
        dueGroups: [AlertGroup],
        presentationRequests: [AlertPresentationRequest],
        backupNotificationRequests: [LocalNotificationBackupRequest]
    ) {
        self.groups = groups
        self.dueGroups = dueGroups
        self.presentationRequests = presentationRequests
        self.backupNotificationRequests = backupNotificationRequests
    }

    public var nextGroup: AlertGroup? {
        groups.first
    }
}

public enum AlertPlanner {
    public static func plan(
        occurrences: [AlertOccurrence],
        states: [String: AlertInteractionState],
        preferences: AlertPreferencesSnapshot,
        now: Date
    ) -> AlertPlan {
        let alertWindowEnd = now.addingTimeInterval(max(0, preferences.leadTime))
        let backupWindowEnd = now.addingTimeInterval(max(0, preferences.backupNotificationWindow))

        let eligibleOccurrences = occurrences.filter { occurrence in
            occurrence.isAlertable
                && occurrence.endDate >= now
                && preferences.enabledProviderIDs.contains(occurrence.providerID)
                && (preferences.selectedSourceIDs.isEmpty || preferences.selectedSourceIDs.contains(occurrence.sourceID))
        }

        let groups = AlertOccurrenceGrouper.groups(for: eligibleOccurrences)
        let dueGroups = groups.filter { group in
            let state = states[group.id]
            guard shouldPresent(group: group, state: state, now: now) else {
                return false
            }

            return group.primaryOccurrence.startDate <= alertWindowEnd
        }

        let presentationRequests = dueGroups.map { group in
            AlertPresentationRequest(
                id: "present:\(group.id)",
                groupID: group.id,
                occurrenceIDs: group.occurrences.map(\.id).sorted(),
                displayData: group.displayData,
                dueAt: group.primaryOccurrence.startDate,
                fullScreen: preferences.fullScreenAlerts
            )
        }

        let backupNotifications = groups
            .filter { $0.primaryOccurrence.startDate <= backupWindowEnd }
            .map { group in
                LocalNotificationBackupRequest(
                    id: "notification:\(group.id)",
                    title: group.primaryOccurrence.title,
                    body: group.primaryOccurrence.calendarTitle,
                    fireDate: group.primaryOccurrence.startDate
                )
            }

        return AlertPlan(
            groups: groups,
            dueGroups: dueGroups,
            presentationRequests: presentationRequests,
            backupNotificationRequests: backupNotifications
        )
    }

    private static func shouldPresent(
        group: AlertGroup,
        state: AlertInteractionState?,
        now: Date
    ) -> Bool {
        guard let state else {
            return true
        }

        if state.occurrenceFingerprint != fingerprint(for: group) {
            return true
        }

        switch state.status {
        case .pending:
            return true
        case .presented, .dismissed, .expired:
            return false
        case .snoozed:
            guard let snoozedUntil = state.snoozedUntil else {
                return true
            }

            return snoozedUntil <= now
        }
    }

    public static func fingerprint(for group: AlertGroup) -> String {
        group.occurrences
            .map { occurrence in
                [
                    occurrence.id,
                    String(Int64(occurrence.startDate.timeIntervalSince1970)),
                    String(Int64(occurrence.endDate.timeIntervalSince1970)),
                    occurrence.status.rawValue
                ].joined(separator: ":")
            }
            .sorted()
            .joined(separator: "|")
    }
}

public enum AlertStateReducer {
    public static func markPresented(
        group: AlertGroup,
        now: Date
    ) -> AlertInteractionState {
        AlertInteractionState(
            groupID: group.id,
            status: .presented,
            occurrenceFingerprint: AlertPlanner.fingerprint(for: group),
            lastPresentedAt: now,
            expiresAt: group.primaryOccurrence.endDate,
            updatedAt: now
        )
    }

    public static func dismiss(
        _ state: AlertInteractionState,
        now: Date
    ) -> AlertInteractionState {
        var next = state
        next.status = .dismissed
        next.dismissedAt = now
        next.snoozedUntil = nil
        next.updatedAt = now
        return next
    }

    public static func snooze(
        _ state: AlertInteractionState,
        until snoozedUntil: Date,
        now: Date
    ) -> AlertInteractionState {
        var next = state
        next.status = .snoozed
        next.snoozedUntil = snoozedUntil
        next.updatedAt = now
        return next
    }

    public static func expire(
        _ state: AlertInteractionState,
        now: Date
    ) -> AlertInteractionState {
        var next = state
        next.status = .expired
        next.updatedAt = now
        return next
    }
}

public enum AlertPolicy {
    public static func eventsToAlert(
        events: [AlertCandidate],
        now: Date,
        leadTime: TimeInterval,
        alertedIDs: Set<String>
    ) -> [AlertCandidate] {
        guard leadTime >= 0 else {
            return []
        }

        let alertWindowEnd = now.addingTimeInterval(leadTime)

        return events
            .filter { event in
                event.isAlertable
                    && event.startDate >= now
                    && event.startDate <= alertWindowEnd
                    && !alertedIDs.contains(event.id)
            }
            .sorted { lhs, rhs in
                lhs.startDate < rhs.startDate
            }
    }
}
