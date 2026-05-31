import NudgebarCore
import Foundation

public enum ProviderRegistry {
    public static let providerOrder: [ProviderID] = [
        .eventKit,
        .googleCalendar,
        .microsoftGraph,
        .calDAV,
        .calendly,
        .calCom,
        .acuity
    ]

    public static let descriptors: [ProviderDescriptor] = [
        ProviderDescriptor(
            id: .eventKit,
            authMode: .macOSPrivacy,
            capabilities: [.sourceDiscovery, .readEvents, .recurringEvents, .cancellationHandling, .localChangeNotifications],
            notes: "Reads calendars configured locally in macOS through EventKit."
        ),
        ProviderDescriptor(
            id: .googleCalendar,
            authMode: .oauthPKCE,
            capabilities: [.accountDiscovery, .sourceDiscovery, .readEvents, .recurringEvents, .cancellationHandling, .deltaSync],
            minimumScopes: [
                "https://www.googleapis.com/auth/calendar.calendarlist.readonly",
                "https://www.googleapis.com/auth/calendar.events.readonly"
            ],
            notes: "Uses Google Calendar read-only scopes and sync tokens."
        ),
        ProviderDescriptor(
            id: .microsoftGraph,
            authMode: .oauthPKCE,
            capabilities: [.accountDiscovery, .sourceDiscovery, .readEvents, .recurringEvents, .cancellationHandling, .deltaSync],
            minimumScopes: ["offline_access", "Calendars.Read"],
            notes: "Uses delegated Microsoft Graph calendar read scopes and delta links."
        ),
        ProviderDescriptor(
            id: .calDAV,
            authMode: .calDAVCredentials,
            capabilities: [.accountDiscovery, .sourceDiscovery, .readEvents, .recurringEvents, .cancellationHandling, .deltaSync, .pollingSync],
            notes: "Uses HTTPS CalDAV discovery, collection sync tokens, and ETags."
        ),
        ProviderDescriptor(
            id: .calendly,
            authMode: .oauthPKCE,
            capabilities: [.accountDiscovery, .sourceDiscovery, .schedulingBookings, .cancellationHandling, .pollingSync],
            minimumScopes: ["default"],
            notes: "Reads scheduled-event bookings for alerting without requiring webhooks."
        ),
        ProviderDescriptor(
            id: .calCom,
            authMode: .apiKey,
            capabilities: [.accountDiscovery, .sourceDiscovery, .schedulingBookings, .cancellationHandling, .pollingSync],
            notes: "Reads Cal.com bookings with OAuth or API-key backed credentials."
        ),
        ProviderDescriptor(
            id: .acuity,
            authMode: .basicAuth,
            capabilities: [.accountDiscovery, .sourceDiscovery, .schedulingBookings, .cancellationHandling, .pollingSync],
            notes: "Reads Acuity appointments with API-key or Basic Auth backed credentials."
        )
    ]

    public static func descriptor(for providerID: ProviderID) -> ProviderDescriptor {
        descriptors.first { $0.id == providerID }!
    }

    public static func makeFixtureProviders(
        now: Date,
        fixtures: [ProviderID: [ProviderEventFixture]] = [:]
    ) -> [FixtureCalendarProvider] {
        providerOrder.map { providerID in
            let account = ConnectedAccount(
                id: "\(providerID.rawValue)-account",
                providerID: providerID,
                displayName: providerID.displayName
            )
            return FixtureCalendarProvider(
                descriptor: descriptor(for: providerID),
                account: account,
                fixtures: fixtures[providerID] ?? [
                    ProviderEventFixture(
                        externalID: "standup",
                        title: "Daily Standup",
                        startDate: now.addingTimeInterval(10 * 60),
                        endDate: now.addingTimeInterval(40 * 60),
                        sourceID: "\(providerID.rawValue)-calendar",
                        sourceTitle: providerID.displayName,
                        location: "Video",
                        updatedAt: now
                    )
                ]
            )
        }
    }
}
