import NudgebarCore
import Combine
import EventKit
import Foundation

@MainActor
final class CalendarAccess: ObservableObject {
    private let store = EKEventStore()

    @Published private(set) var authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @Published private(set) var calendars: [CalendarSource] = []
    @Published private(set) var lastError: String?

    var isAuthorized: Bool {
        Self.isAuthorized(authorizationStatus)
    }

    var statusLabel: String {
        if #available(macOS 14.0, *) {
            switch authorizationStatus {
            case .fullAccess:
                return "Full access"
            case .writeOnly:
                return "Write-only access"
            default:
                break
            }
        }

        switch authorizationStatus {
        case .notDetermined:
            return "Not requested"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .fullAccess:
            return "Full access"
        case .writeOnly:
            return "Write-only access"
        @unknown default:
            return "Unknown"
        }
    }

    func refreshAuthorization() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if isAuthorized {
            loadCalendars()
        }
    }

    func requestAccess() async {
        do {
            let granted: Bool

            if #available(macOS 14.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await requestLegacyAccess()
            }

            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            lastError = granted ? nil : "Calendar access was not granted."

            if granted {
                loadCalendars()
            }
        } catch {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            lastError = error.localizedDescription
        }
    }

    func upcomingEvents(
        from startDate: Date,
        to endDate: Date,
        enabledCalendarIDs: Set<String>
    ) -> [AlertCandidate] {
        guard isAuthorized, !enabledCalendarIDs.isEmpty else {
            return []
        }

        let selectedCalendars = store
            .calendars(for: .event)
            .filter { enabledCalendarIDs.contains($0.calendarIdentifier) }

        guard !selectedCalendars.isEmpty else {
            return []
        }

        let predicate = store.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: selectedCalendars
        )

        return store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .compactMap(makeAlertCandidate)
    }

    private static func isAuthorized(_ status: EKAuthorizationStatus) -> Bool {
        if #available(macOS 14.0, *) {
            return status == .fullAccess || status == .authorized
        }

        return status == .authorized
    }

    private func loadCalendars() {
        calendars = store
            .calendars(for: .event)
            .map { calendar in
                CalendarSource(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    sourceTitle: calendar.source.title
                )
            }
            .sorted { lhs, rhs in
                lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private func requestLegacyAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            store.requestAccess(to: .event) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    private func makeAlertCandidate(from event: EKEvent) -> AlertCandidate? {
        guard let startDate = event.startDate, let endDate = event.endDate else {
            return nil
        }

        let stableID: String
        if let eventIdentifier = event.eventIdentifier, !eventIdentifier.isEmpty {
            stableID = eventIdentifier
        } else {
            stableID = event.calendarItemIdentifier
        }

        return AlertCandidate(
            id: stableID,
            title: event.title?.isEmpty == false ? event.title : "Untitled event",
            startDate: startDate,
            endDate: endDate,
            calendarTitle: event.calendar.title,
            location: event.location
        )
    }
}
