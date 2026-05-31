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

    /// Upcoming events from now through end of tomorrow, sorted ascending, capped at 25.
    @Published private(set) var upcomingEvents: [AlertCandidate] = []

    var nextUpcomingEvent: AlertCandidate? {
        upcomingEvents.first
    }

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

        let monitor = EventMonitor(
            calendarAccess: calendarAccess,
            preferences: preferences,
            snoozeStore: snoozeStore,
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
        upcomingEvents = UpcomingEventsList.filter(events, now: now)
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
    private let present: @MainActor (AlertCandidate) -> Void
    private let onTick: @MainActor () -> Void
    private var task: Task<Void, Never>?
    private var alertedEvents: [String: Date] = [:]

    init(
        calendarAccess: CalendarAccess,
        preferences: AlertPreferences,
        snoozeStore: SnoozeStore,
        present: @escaping @MainActor (AlertCandidate) -> Void,
        onTick: @escaping @MainActor () -> Void = {}
    ) {
        self.calendarAccess = calendarAccess
        self.preferences = preferences
        self.snoozeStore = snoozeStore
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

        guard calendarAccess.isAuthorized else {
            onTick()
            return
        }

        let now = Date()

        // Re-admit events whose snooze has elapsed so they can fire again.
        for (id, until) in snoozeStore.snoozedUntil where until <= now {
            alertedEvents.removeValue(forKey: id)
            snoozeStore.clear(eventID: id)
        }

        // Look ahead by the largest effective lead so per-calendar overrides are covered.
        let lookAhead = max(preferences.maxEffectiveLeadSeconds, 60)
        let endDate = now.addingTimeInterval(lookAhead)
        let enabledCalendarIDs = preferences.enabledCalendarIDs(from: calendarAccess.calendars)
        let upcomingEvents = calendarAccess.upcomingEvents(
            from: now,
            to: endDate,
            enabledCalendarIDs: enabledCalendarIDs
        )

        let activeSnoozes = Set(snoozeStore.snoozedUntil.filter { $0.value > now }.keys)
        let suppressed = Set(alertedEvents.keys).union(activeSnoozes)

        let dueEvents = upcomingEvents
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
