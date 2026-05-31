import NudgebarCore
import NudgebarProviders
import EventKit
import Foundation

public final class EventKitCalendarConnector: CalendarSyncProvider {
    public let descriptor = ProviderRegistry.descriptor(for: .eventKit)
    private let store: EKEventStore

    public init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    public func discoverAccounts() async throws -> [ConnectedAccount] {
        [
            ConnectedAccount(
                id: "eventkit-local",
                providerID: .eventKit,
                displayName: "Local macOS Calendars"
            )
        ]
    }

    public func discoverSources(for account: ConnectedAccount) async throws -> [CalendarSource] {
        store.calendars(for: .event).map { calendar in
            CalendarSource(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                sourceTitle: calendar.source.title,
                providerID: .eventKit,
                accountID: account.id,
                externalID: calendar.calendarIdentifier
            )
        }
        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    public func initialSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult {
        try sync(request: request)
    }

    public func incrementalSync(request: ProviderSyncRequest) async throws -> ProviderSyncResult {
        try sync(request: request)
    }

    private func sync(request: ProviderSyncRequest) throws -> ProviderSyncResult {
        let selectedIDs = Set(request.sources.map(\.id))
        let calendars = store
            .calendars(for: .event)
            .filter { selectedIDs.isEmpty || selectedIDs.contains($0.calendarIdentifier) }

        let predicate = store.predicateForEvents(
            withStart: request.windowStart,
            end: request.windowEnd,
            calendars: calendars
        )

        let occurrences = store.events(matching: predicate).compactMap { event in
            normalize(event, accountID: request.account.id)
        }

        let cursor = SyncCursor(
            providerID: .eventKit,
            accountID: request.account.id,
            sourceID: request.sources.first?.id ?? "all",
            value: String(Int64(Date().timeIntervalSince1970)),
            updatedAt: Date(),
            metadata: ["refresh": "eventkit-notification-or-window-fetch"]
        )

        return ProviderSyncResult(
            occurrences: occurrences,
            nextCursor: cursor,
            completedAt: cursor.updatedAt
        )
    }

    private func normalize(_ event: EKEvent, accountID: String) -> AlertOccurrence? {
        guard let startDate = event.startDate, let endDate = event.endDate else {
            return nil
        }

        let externalID: String
        if let eventIdentifier = event.eventIdentifier, !eventIdentifier.isEmpty {
            externalID = eventIdentifier
        } else {
            externalID = event.calendarItemIdentifier
        }

        return AlertOccurrence(
            id: "eventkit:\(accountID):\(event.calendar.calendarIdentifier):\(externalID)",
            title: event.title?.isEmpty == false ? event.title : "Untitled event",
            startDate: startDate,
            endDate: endDate,
            calendarTitle: event.calendar.title,
            location: event.location,
            providerID: .eventKit,
            accountID: accountID,
            sourceID: event.calendar.calendarIdentifier,
            externalID: externalID,
            timeZoneIdentifier: event.timeZone?.identifier,
            status: event.status == .canceled ? .cancelled : .confirmed,
            isAllDay: event.isAllDay,
            lastModified: event.lastModifiedDate
        )
    }
}
