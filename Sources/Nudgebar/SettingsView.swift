import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        SettingsContent(
            model: model,
            preferences: model.preferences,
            calendarAccess: model.calendarAccess
        )
        .onAppear {
            model.start()
        }
    }
}

private struct SettingsContent: View {
    let model: AppModel
    @ObservedObject var preferences: AlertPreferences
    @ObservedObject var calendarAccess: CalendarAccess

    var body: some View {
        Form {
            Section("Alerts") {
                Toggle("Show full-screen alerts", isOn: $preferences.fullScreenAlerts)

                Picker("Lead time", selection: $preferences.leadMinutes) {
                    ForEach(AlertPreferences.allowedLeadMinutes, id: \.self) { minutes in
                        Text(leadTimeLabel(minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.segmented)

                Stepper(
                    value: $preferences.pollSeconds,
                    in: 10...300,
                    step: 10
                ) {
                    Text("Check calendars every \(preferences.pollSeconds) seconds")
                }
            }

            Section("Calendars") {
                if !calendarAccess.isAuthorized {
                    Button("Grant Calendar Access") {
                        model.requestCalendarAccess()
                    }
                } else if calendarAccess.calendars.isEmpty {
                    Text("No calendars found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(calendarAccess.calendars) { calendar in
                        Toggle(
                            isOn: Binding(
                                get: {
                                    preferences.isCalendarEnabled(id: calendar.id)
                                },
                                set: { enabled in
                                    preferences.setCalendar(id: calendar.id, enabled: enabled)
                                }
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(calendar.title)
                                Text(calendar.sourceTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                HStack {
                    Button("Refresh Calendars") {
                        model.refreshCalendars()
                    }

                    Button("Test Alert") {
                        model.testAlert()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 520)
    }

    private func leadTimeLabel(_ minutes: Int) -> String {
        minutes == 0 ? "At start" : "\(minutes) min"
    }
}
