import NudgebarCore
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let preferences: AlertPreferences
    let calendarAccess: CalendarAccess
    let presenter: AlertPresenter

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

        let monitor = EventMonitor(
            calendarAccess: calendarAccess,
            preferences: preferences,
            presenter: presenter
        )
        self.monitor = monitor
        monitor.start()
    }

    func requestCalendarAccess() {
        Task {
            await calendarAccess.requestAccess()
        }
    }

    func refreshCalendars() {
        calendarAccess.refreshAuthorization()
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
    private var task: Task<Void, Never>?
    private var alertedEvents: [String: Date] = [:]

    init(
        calendarAccess: CalendarAccess,
        preferences: AlertPreferences,
        presenter: AlertPresenter
    ) {
        self.calendarAccess = calendarAccess
        self.preferences = preferences
        self.presenter = presenter
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
    }

    private func pruneAlertHistory(relativeTo now: Date) {
        let cutoff = now.addingTimeInterval(-24 * 60 * 60)
        alertedEvents = alertedEvents.filter { _, startDate in
            startDate >= cutoff
        }
    }
}
