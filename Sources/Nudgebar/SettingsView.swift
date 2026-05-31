import NudgebarCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            GeneralTab(model: model, preferences: model.preferences, calendarAccess: model.calendarAccess)
                .tabItem { Label("General", systemImage: "gearshape") }
            ConnectorsTab()
                .tabItem { Label("Connectors", systemImage: "link") }
            AlertsTab(model: model, preferences: model.preferences, calendarAccess: model.calendarAccess)
                .tabItem { Label("Alerts", systemImage: "bell") }
            ShortcutsTab(preferences: model.preferences)
                .tabItem { Label("Shortcuts", systemImage: "command") }
        }
        .frame(width: 560, height: 540)
        .onAppear { model.start() }
    }
}

// MARK: - General

private struct GeneralTab: View {
    let model: AppModel
    @ObservedObject var preferences: AlertPreferences
    @ObservedObject var calendarAccess: CalendarAccess

    var body: some View {
        Form {
            Section("Alerts") {
                Toggle("Show full-screen alerts", isOn: $preferences.fullScreenAlerts)
                Picker("Lead time", selection: $preferences.leadMinutes) {
                    ForEach(AlertPreferences.allowedLeadMinutes, id: \.self) { minutes in
                        Text(minutes == 0 ? "At start" : "\(minutes) min").tag(minutes)
                    }
                }
                Stepper(value: $preferences.pollSeconds, in: 10...300, step: 10) {
                    Text("Check calendars every \(preferences.pollSeconds)s")
                }
            }

            Section("Calendars") {
                if !calendarAccess.isAuthorized {
                    Button("Grant Calendar Access") { model.requestCalendarAccess() }
                } else if calendarAccess.calendars.isEmpty {
                    Text("No calendars found.").foregroundStyle(.secondary)
                } else {
                    ForEach(calendarAccess.calendars) { calendar in
                        Toggle(isOn: Binding(
                            get: { preferences.isCalendarEnabled(id: calendar.id) },
                            set: { preferences.setCalendar(id: calendar.id, enabled: $0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(calendar.title)
                                Text(calendar.sourceTitle).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                HStack {
                    Button("Refresh Calendars") { model.refreshCalendars() }
                    Button("Test Alert") { model.testAlert() }
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Connectors

private struct ConnectorsTab: View {
    private let active = "EventKit (local macOS calendars)"
    private let planned = ["Google Calendar", "Microsoft 365", "CalDAV", "Calendly", "Cal.com", "Acuity"]

    var body: some View {
        Form {
            Section("Active") {
                Label(active, systemImage: "checkmark.circle.fill").foregroundStyle(.primary)
            }
            Section("Planned") {
                ForEach(planned, id: \.self) { name in
                    Label(name, systemImage: "circle.dashed").foregroundStyle(.secondary)
                }
            }
            Section {
                Text("Cloud connectors are provided by the Nudgebar foundation and will be enabled in a future update. Alerts currently read your local macOS calendars via EventKit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Alerts

private struct AlertsTab: View {
    let model: AppModel
    @ObservedObject var preferences: AlertPreferences
    @ObservedObject var calendarAccess: CalendarAccess

    private static let autoDismissOptions = [0, 5, 10, 15, 30, 60, 120, 300]

    var body: some View {
        Form {
            Section("Sound") {
                Picker("Alert sound", selection: $preferences.soundName) {
                    ForEach(AlertSoundCatalog.sounds) { sound in
                        Text(sound.label).tag(sound.name)
                    }
                }
                Button("Preview") { model.previewSound(named: preferences.soundName) }
            }

            Section("Auto-dismiss") {
                Picker("Auto-dismiss after", selection: $preferences.autoDismissSeconds) {
                    ForEach(Self.autoDismissOptions, id: \.self) { seconds in
                        Text(autoDismissLabel(seconds)).tag(seconds)
                    }
                }
            }

            Section("Delivery") {
                Toggle("Fall back to notifications", isOn: $preferences.notificationFallbackEnabled)
                Toggle("Respect Focus / Do Not Disturb", isOn: $preferences.respectFocus)
                Text("Focus detection is best-effort on macOS; the toggle is the reliable control.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if calendarAccess.isAuthorized && !calendarAccess.calendars.isEmpty {
                Section("Per-calendar rules") {
                    ForEach(calendarAccess.calendars) { calendar in
                        CalendarRuleRow(calendar: calendar, preferences: preferences)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func autoDismissLabel(_ seconds: Int) -> String {
        if seconds == AlertPreferences.autoDismissNeverSentinel { return "Never" }
        return seconds < 60 ? "\(seconds)s" : "\(seconds / 60) min"
    }
}

private struct CalendarRuleRow: View {
    let calendar: CalendarSource
    @ObservedObject var preferences: AlertPreferences

    private static let leadDefault = -1

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(calendar.title).font(.subheadline)
            HStack {
                Picker("Lead", selection: leadBinding) {
                    Text("Default").tag(Self.leadDefault)
                    ForEach(AlertPreferences.allowedLeadMinutes, id: \.self) { minutes in
                        Text(minutes == 0 ? "At start" : "\(minutes)m").tag(minutes)
                    }
                }
                .labelsHidden()
                Picker("Sound", selection: soundBinding) {
                    Text("Default").tag("")
                    ForEach(AlertSoundCatalog.sounds) { sound in
                        Text(sound.label).tag(sound.name)
                    }
                }
                .labelsHidden()
            }
        }
        .padding(.vertical, 2)
    }

    private var leadBinding: Binding<Int> {
        Binding(
            get: { preferences.rule(for: calendar.id)?.leadMinutesOverride ?? Self.leadDefault },
            set: { newValue in
                var rule = preferences.rule(for: calendar.id) ?? CalendarAlertRule()
                rule.leadMinutesOverride = newValue == Self.leadDefault ? nil : newValue
                preferences.setRule(rule, for: calendar.id)
            }
        )
    }

    private var soundBinding: Binding<String> {
        Binding(
            get: { preferences.rule(for: calendar.id)?.soundOverride ?? "" },
            set: { newValue in
                var rule = preferences.rule(for: calendar.id) ?? CalendarAlertRule()
                rule.soundOverride = newValue.isEmpty ? nil : newValue
                preferences.setRule(rule, for: calendar.id)
            }
        )
    }
}

// MARK: - Shortcuts

private struct ShortcutsTab: View {
    @ObservedObject var preferences: AlertPreferences
    @StateObject private var recorder = ShortcutRecorder()
    @State private var recordingAction: ShortcutAction?
    @State private var conflictMessage: String?

    var body: some View {
        Form {
            Section("Global shortcuts") {
                ForEach(ShortcutAction.allCases, id: \.self) { action in
                    HStack {
                        Text(action.title)
                        Spacer()
                        Text(preferences.shortcut(for: action)?.displayString ?? "Not set")
                            .foregroundStyle(.secondary)
                            .monospaced()
                        Button(recordingAction == action ? "Recording…" : "Record") {
                            beginRecording(action)
                        }
                        .disabled(recordingAction != nil && recordingAction != action)
                        if preferences.shortcut(for: action) != nil {
                            Button("Clear") { preferences.setShortcut(nil, for: action) }
                        }
                    }
                }
            }

            if let conflictMessage {
                Section { Text(conflictMessage).font(.caption).foregroundStyle(.red) }
            }

            Section {
                Text("Global shortcuts require Accessibility permission (System Settings › Privacy & Security › Accessibility). Without it, shortcuts work only while Nudgebar is focused.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func beginRecording(_ action: ShortcutAction) {
        conflictMessage = nil
        recordingAction = action
        recorder.record { binding in
            if ShortcutBinding.conflicts(binding, in: preferences.shortcuts, excluding: action) {
                conflictMessage = "\(binding.displayString) is already assigned to another action."
            } else {
                preferences.setShortcut(binding, for: action)
            }
            recordingAction = nil
        }
    }
}
