import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        MenuBarContent(
            model: model,
            preferences: model.preferences,
            calendarAccess: model.calendarAccess
        )
        .onAppear {
            model.start()
        }
    }
}

private struct MenuBarContent: View {
    let model: AppModel
    @ObservedObject var preferences: AlertPreferences
    @ObservedObject var calendarAccess: CalendarAccess

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nudgebar")
                .font(.headline)

            Text("Calendar access: \(calendarAccess.statusLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let lastError = calendarAccess.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            if !calendarAccess.isAuthorized {
                Button("Grant Calendar Access") {
                    model.requestCalendarAccess()
                }
            }

            Divider()

            Toggle("Full-screen alerts", isOn: $preferences.fullScreenAlerts)

            Picker("Alert lead time", selection: $preferences.leadMinutes) {
                ForEach(AlertPreferences.allowedLeadMinutes, id: \.self) { minutes in
                    Text(leadTimeLabel(minutes)).tag(minutes)
                }
            }

            Button("Test Alert") {
                model.testAlert()
            }

            Button("Refresh Calendars") {
                model.refreshCalendars()
            }

            Divider()

            Button("Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }

            Button("Quit Nudgebar") {
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 280)
    }

    private func leadTimeLabel(_ minutes: Int) -> String {
        minutes == 0 ? "At start" : "\(minutes) min before"
    }
}
