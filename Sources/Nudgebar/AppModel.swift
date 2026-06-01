import NudgebarAuth
import NudgebarCore
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let preferences: AlertPreferences
    let calendarAccess: CalendarAccess
    let presenter: AlertPresenter
    let ticker = CountdownTicker()
    let snoozeStore = SnoozeStore()
    let connectorStore = ConnectorStore()

    /// Upcoming events from now through end of tomorrow, sorted ascending, capped at 25.
    @Published private(set) var upcomingEvents: [AlertCandidate] = []

    var nextUpcomingEvent: AlertCandidate? {
        // The menu-bar countdown is for the next timed event; all-day events still
        // appear in the popover but have no meaningful countdown.
        upcomingEvents.first { !$0.isAllDay }
    }

    /// Set by the app delegate to open the settings window from the popover/menu.
    var openSettingsAction: (() -> Void)?

    @Published var connectError: String?
    private let oauthFlow = OAuthFlow()

    private let notifier = NotificationDelivery()
    private let previewPlayer = SoundPlayer()
    private var monitor: EventMonitor?
    private var alertWindow: AlertWindowController?
    private var hasStarted = false

    // macOS exposes no public Focus/DND API; the "respect Focus" toggle is the
    // reliable control and this stays false (best-effort) until that changes.
    private var focusActive: Bool { false }

    init(defaults: UserDefaults = .standard) {
        self.preferences = AlertPreferences(defaults: defaults)
        self.calendarAccess = CalendarAccess()
        self.presenter = AlertPresenter()
    }

    func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true
        calendarAccess.refreshAuthorization()
        notifier.requestAuthorization()
        refreshUpcoming()

        // Prompt for calendar access on first launch so events load without the
        // user having to hunt for the in-popover Grant button.
        if calendarAccess.isUndetermined {
            requestCalendarAccess()
        }

        let monitor = EventMonitor(
            calendarAccess: calendarAccess,
            preferences: preferences,
            snoozeStore: snoozeStore,
            connectorStore: connectorStore,
            present: { [weak self] event in self?.fireAlert(event: event) },
            onTick: { [weak self] in self?.refreshUpcoming() }
        )
        self.monitor = monitor
        monitor.start()
    }

    func requestCalendarAccess() {
        Task {
            await calendarAccess.requestAccess()
            refreshUpcoming()
        }
    }

    func refreshCalendars() {
        calendarAccess.refreshAuthorization()
        refreshUpcoming()
    }

    /// Recompute the upcoming-events window and refresh the countdown cadence.
    func refreshUpcoming(now: Date = .now) {
        let windowEnd = UpcomingEventsList.endOfTomorrow(from: now)
        let enabledCalendarIDs = preferences.enabledCalendarIDs(from: calendarAccess.calendars)
        let events = calendarAccess.upcomingEvents(
            from: now,
            to: windowEnd,
            enabledCalendarIDs: enabledCalendarIDs
        )
        snoozeStore.clearExpired(now: now)
        // Merge EventKit events with synced cloud-connector occurrences.
        upcomingEvents = UpcomingEventsList.filter(events + connectorStore.occurrences, now: now)
        ticker.update(nextEventStart: nextUpcomingEvent?.startDate, now: now)
    }

    /// Route a due event through the delivery decision: full-screen window,
    /// notification fallback, or suppressed.
    func fireAlert(event: AlertCandidate) {
        let decision = AlertDeliveryDecider.decide(
            fullScreenEnabled: preferences.fullScreenAlerts,
            respectFocus: preferences.respectFocus,
            focusActive: focusActive,
            notificationFallback: preferences.notificationFallbackEnabled
        )
        switch decision {
        case .fullScreen:
            let sound = preferences.effectiveSettings(for: event).soundName
            alertWindowController().present(
                event: event,
                autoDismissSeconds: preferences.autoDismissSeconds,
                soundName: sound
            )
        case .notification:
            notifier.deliver(event: event)
        case .suppressed:
            break
        }
    }

    /// Snooze an event, capping the deadline at the event start so a long snooze
    /// collapses to the start time.
    func snooze(event: AlertCandidate, minutes: Int, now: Date = .now) {
        let requested = now.addingTimeInterval(TimeInterval(max(0, minutes) * 60))
        snoozeStore.snooze(eventID: event.id, until: min(requested, event.startDate))
        refreshUpcoming(now: now)
    }

    func snoozeAllAlerts() {
        alertWindow?.snoozeAllVisible(minutes: AlertPreferences.defaultSnoozeMinutes)
    }

    func dismissAllAlerts() {
        alertWindow?.dismissAllVisible()
    }

    /// Connect a cloud provider via OAuth, store its refresh token, and start syncing.
    func connect(providerID: ProviderID) {
        connectError = nil
        Task { await performConnect(providerID) }
    }

    /// Save an OAuth client ID/secret entered in the app's setup sheet.
    func saveOAuthClient(providerID: ProviderID, clientID: String, clientSecret: String?) {
        var config = ConnectorConfig.load()
        let secret = (clientSecret?.isEmpty == false) ? clientSecret : nil
        switch providerID {
        case .calendly: config.calendlyClientID = clientID; config.calendlyClientSecret = secret
        default: break
        }
        ConnectorConfig.save(config)
        objectWillChange.send()
    }

    private func performConnect(_ providerID: ProviderID) async {
        let config = ConnectorConfig.load()
        guard let clientID = config.oauthClientID(for: providerID), !clientID.isEmpty else {
            connectError = "\(providerID.displayName) isn't set up yet. Add its OAuth client ID in Settings."
            return
        }
        let (redirectURI, callbackScheme) = ConnectorConfig.redirect(for: providerID, clientID: clientID)
        guard let metadata = ProviderAuthCatalog.metadata(providerID: providerID, clientID: clientID, redirectURI: redirectURI) else {
            connectError = "Couldn't build the OAuth request for \(providerID.displayName)."
            return
        }
        do {
            let extra: [String: String] = [:]
            let tokens = try await oauthFlow.authorize(
                metadata: metadata,
                callbackScheme: callbackScheme,
                clientSecret: config.oauthClientSecret(for: providerID),
                extraAuthParameters: extra
            )
            guard let refreshToken = tokens.refreshToken else {
                connectError = "\(providerID.displayName) did not return a refresh token (re-consent may be required)."
                return
            }
            let accountID = "\(providerID.rawValue)-\(UUID().uuidString.prefix(8))"
            let reference = ConnectorCredentials.oauthRefreshReference(providerID: providerID, accountID: accountID)
            try ConnectorCredentials.save(refreshToken, reference: reference, kind: .oauthRefreshToken)
            connectorStore.addAccount(ConnectedAccount(
                id: accountID,
                providerID: providerID,
                displayName: providerID.displayName,
                credentialReference: reference
            ))
            refreshUpcoming()
        } catch OAuthError.cancelled {
            // User dismissed the auth sheet; nothing to report.
        } catch {
            connectError = error.localizedDescription
        }
    }

    /// Fields the credential-entry sheet should collect for a non-OAuth provider.
    func credentialFields(for providerID: ProviderID) -> [ConnectorCredentialField] {
        switch providerID {
        case .calCom:
            return [ConnectorCredentialField(key: "apiKey", label: "API key", isSecret: true)]
        case .acuity:
            return [
                ConnectorCredentialField(key: "userID", label: "User ID", isSecret: false),
                ConnectorCredentialField(key: "apiKey", label: "API key", isSecret: true)
            ]
        case .calDAV:
            return [
                ConnectorCredentialField(key: "server", label: "Server URL", isSecret: false),
                ConnectorCredentialField(key: "username", label: "Username", isSecret: false),
                ConnectorCredentialField(key: "password", label: "App password", isSecret: true)
            ]
        case .eventKit, .googleCalendar, .microsoftGraph, .calendly:
            return []
        }
    }

    /// Connect a credential-based provider (API key / Basic auth) from entered values.
    func connectWithCredentials(providerID: ProviderID, values: [String: String]) {
        connectError = nil
        let accountID = "\(providerID.rawValue)-\(UUID().uuidString.prefix(8))"
        let secret: String
        switch providerID {
        case .calCom:
            secret = values["apiKey"] ?? ""
        case .acuity:
            secret = "\(values["userID"] ?? ""):\(values["apiKey"] ?? "")"
        case .calDAV:
            secret = [values["server"], values["username"], values["password"]].compactMap { $0 }.joined(separator: "\u{1F}")
        default:
            secret = ""
        }
        guard secret.contains(where: { !$0.isWhitespace && $0 != ":" && $0 != "\u{1F}" }) else {
            connectError = "Please fill in the \(providerID.displayName) credentials."
            return
        }
        let reference = ConnectorCredentials.apiKeyReference(providerID: providerID, accountID: accountID)
        do {
            try ConnectorCredentials.save(secret, reference: reference, kind: .apiKey)
        } catch {
            connectError = error.localizedDescription
            return
        }
        connectorStore.addAccount(ConnectedAccount(
            id: accountID,
            providerID: providerID,
            displayName: providerID.displayName,
            credentialReference: reference
        ))
        refreshUpcoming()
    }

    func disconnect(providerID: ProviderID) {
        for account in connectorStore.accounts where account.providerID == providerID {
            if let reference = account.credentialReference {
                try? KeychainCredentialStore().delete(reference: reference)
            }
            connectorStore.removeAccount(id: account.id)
        }
        refreshUpcoming()
    }

    func previewSound(named name: String) {
        previewPlayer.playOnce(name: name)
    }

    func testAlert() {
        fireAlert(event: .sample())
    }

    private func alertWindowController() -> AlertWindowController {
        if let alertWindow {
            return alertWindow
        }
        let controller = AlertWindowController(onSnooze: { [weak self] event, minutes in
            self?.snooze(event: event, minutes: minutes)
        })
        alertWindow = controller
        return controller
    }
}

@MainActor
final class EventMonitor {
    private let calendarAccess: CalendarAccess
    private let preferences: AlertPreferences
    private let snoozeStore: SnoozeStore
    private let connectorStore: ConnectorStore
    private let present: @MainActor (AlertCandidate) -> Void
    private let onTick: @MainActor () -> Void
    private var task: Task<Void, Never>?
    private var alertedEvents: [String: Date] = [:]

    init(
        calendarAccess: CalendarAccess,
        preferences: AlertPreferences,
        snoozeStore: SnoozeStore,
        connectorStore: ConnectorStore,
        present: @escaping @MainActor (AlertCandidate) -> Void,
        onTick: @escaping @MainActor () -> Void = {}
    ) {
        self.calendarAccess = calendarAccess
        self.preferences = preferences
        self.snoozeStore = snoozeStore
        self.connectorStore = connectorStore
        self.present = present
        self.onTick = onTick
    }

    deinit {
        task?.cancel()
    }

    func start() {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }

                await self.tick()

                let pollSeconds = max(10, self.preferences.pollSeconds)
                try? await Task.sleep(nanoseconds: UInt64(pollSeconds) * 1_000_000_000)
            }
        }
    }

    private func tick() async {
        calendarAccess.refreshAuthorization()

        let now = Date()

        // Re-admit events whose snooze has elapsed so they can fire again.
        for (id, until) in snoozeStore.snoozedUntil where until <= now {
            alertedEvents.removeValue(forKey: id)
            snoozeStore.clear(eventID: id)
        }

        // Sync cloud connectors over the popover window (independent of EventKit auth).
        await connectorStore.sync(windowStart: now, windowEnd: UpcomingEventsList.endOfTomorrow(from: now))

        // Look ahead by the largest effective lead so per-calendar overrides are covered.
        let lookAhead = max(preferences.maxEffectiveLeadSeconds, 60)
        let endDate = now.addingTimeInterval(lookAhead)
        let eventKitEvents = calendarAccess.isAuthorized
            ? calendarAccess.upcomingEvents(
                from: now,
                to: endDate,
                enabledCalendarIDs: preferences.enabledCalendarIDs(from: calendarAccess.calendars)
            )
            : []
        let candidates = eventKitEvents + connectorStore.occurrences

        let activeSnoozes = Set(snoozeStore.snoozedUntil.filter { $0.value > now }.keys)
        let suppressed = Set(alertedEvents.keys).union(activeSnoozes)

        let dueEvents = candidates
            .filter { event in
                guard event.isAlertable, !suppressed.contains(event.id) else {
                    return false
                }
                let lead = TimeInterval(max(0, preferences.effectiveSettings(for: event).leadMinutes) * 60)
                return event.startDate >= now && event.startDate <= now.addingTimeInterval(lead)
            }
            .sorted { $0.startDate < $1.startDate }

        for event in dueEvents {
            alertedEvents[event.id] = event.startDate
            present(event)
        }

        pruneAlertHistory(relativeTo: now)
        onTick()
    }

    private func pruneAlertHistory(relativeTo now: Date) {
        let cutoff = now.addingTimeInterval(-24 * 60 * 60)
        alertedEvents = alertedEvents.filter { _, startDate in
            startDate >= cutoff
        }
    }
}
