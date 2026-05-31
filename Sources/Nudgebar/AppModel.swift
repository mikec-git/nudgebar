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

    private var monitor: EventMonitor?
    private var hasStarted = false

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
        refreshUpcoming()

        let monitor = EventMonitor(
            calendarAccess: calendarAccess,
            preferences: preferences,
            presenter: presenter,
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

    func testAlert() {
        presenter.present(
            event: .sample(),
            fullScreen: preferences.fullScreenAlerts
        )
    }
}

@MainActor
final class EventMonitor {
    private let calendarAccess: CalendarAccess
    private let preferences: AlertPreferences
    private let presenter: AlertPresenter
    private let onTick: @MainActor () -> Void
    private var task: Task<Void, Never>?
    private var alertedEvents: [String: Date] = [:]

    init(
        calendarAccess: CalendarAccess,
        preferences: AlertPreferences,
        presenter: AlertPresenter,
        onTick: @escaping @MainActor () -> Void = {}
    ) {
        self.calendarAccess = calendarAccess
        self.preferences = preferences
        self.presenter = presenter
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
        let endDate = now.addingTimeInterval(max(preferences.leadTime, 60))
        let enabledCalendarIDs = preferences.enabledCalendarIDs(from: calendarAccess.calendars)
        let upcomingEvents = calendarAccess.upcomingEvents(
            from: now,
            to: endDate,
            enabledCalendarIDs: enabledCalendarIDs
        )
        let dueEvents = AlertPolicy.eventsToAlert(
            events: upcomingEvents,
            now: now,
            leadTime: preferences.leadTime,
            alertedIDs: Set(alertedEvents.keys)
        )

        for event in dueEvents {
            alertedEvents[event.id] = event.startDate
            presenter.present(event: event, fullScreen: preferences.fullScreenAlerts)
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
