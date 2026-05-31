import NudgebarCore
import ServiceManagement
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, calendars, connectors, alerts, shortcuts, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .calendars: return "Calendars"
        case .connectors: return "Connectors"
        case .alerts: return "Alerts"
        case .shortcuts: return "Shortcuts"
        case .about: return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .calendars: return "calendar"
        case .connectors: return "link"
        case .alerts: return "bell"
        case .shortcuts: return "command"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var section: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $section)
            Rectangle().fill(Brand.rule).frame(width: 1)
            ScrollView {
                content
                    .padding(28)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Brand.ink)
        }
        .frame(width: 720, height: 560)
        .environment(\.colorScheme, .dark)
        .tint(Brand.blush)
        .onAppear { model.start() }
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .general: GeneralSection(model: model, preferences: model.preferences)
        case .calendars: CalendarsSection(model: model, preferences: model.preferences, calendarAccess: model.calendarAccess)
        case .connectors: ConnectorsSection()
        case .alerts: AlertsSection(model: model, preferences: model.preferences)
        case .shortcuts: ShortcutsSection(preferences: model.preferences)
        case .about: AboutSection()
        }
    }
}

// MARK: - Sidebar

private struct SettingsSidebar: View {
    @Binding var selection: SettingsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                RingLogo(state: .active).frame(width: 20, height: 20)
                Wordmark(size: 15)
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 14)

            ForEach(SettingsSection.allCases) { item in
                Button { selection = item } label: {
                    HStack(spacing: 9) {
                        Image(systemName: item.systemImage)
                            .frame(width: 16)
                            .foregroundStyle(selection == item ? Brand.blush : Brand.stone)
                        Text(item.title)
                            .font(Brand.font(13, selection == item ? .medium : .regular))
                            .foregroundStyle(selection == item ? Brand.blush : Brand.sand)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(selection == item ? Brand.blush.opacity(0.12) : .clear)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }

            Spacer()
            Text("Nudgebar v0.1.0")
                .font(Brand.font(11))
                .foregroundStyle(Brand.stone)
                .padding(14)
        }
        .frame(width: 188)
        .frame(maxHeight: .infinity)
        .background(Brand.ember)
    }
}

// MARK: - Reusable pieces

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(Brand.font(22, .semibold)).foregroundStyle(Brand.blush)
            Text(subtitle).font(Brand.font(13)).foregroundStyle(Brand.stone)
        }
        .padding(.bottom, 6)
    }
}

private struct SettingsGroup<Content: View>: View {
    let eyebrow: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(eyebrow.uppercased())
                .font(Brand.font(10, .semibold)).kerning(0.7)
                .foregroundStyle(Brand.stone)
                .padding(.bottom, 7)
            VStack(spacing: 0) { content }
                .background(RoundedRectangle(cornerRadius: 12).fill(Brand.ember))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Brand.rule, lineWidth: 1))
        }
        .padding(.bottom, 18)
    }
}

private struct SettingRow<Control: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Brand.font(13, .medium)).foregroundStyle(Brand.blush)
                if let subtitle {
                    Text(subtitle).font(Brand.font(11)).foregroundStyle(Brand.stone)
                }
            }
            Spacer()
            control
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

private struct RowDivider: View {
    var body: some View { Rectangle().fill(Brand.rule).frame(height: 1).padding(.leading, 14) }
}

private struct BrandMenu<T: Hashable>: View {
    let options: [T]
    let label: (T) -> String
    @Binding var selection: T
    var onChange: () -> Void = {}

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(label(option)) { selection = option; onChange() }
            }
        } label: {
            HStack(spacing: 5) {
                Text(label(selection)).font(Brand.font(12, .medium))
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
            }
            .foregroundStyle(Brand.blush)
            .padding(.horizontal, 11).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7).fill(Brand.blush.opacity(0.10)))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

// MARK: - General

private struct GeneralSection: View {
    let model: AppModel
    @ObservedObject var preferences: AlertPreferences
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "General", subtitle: "How and when Nudgebar nudges you.")

            SettingsGroup(eyebrow: "Alerts") {
                SettingRow(title: "Full-screen alerts", subtitle: "Take over the screen when an event is due") {
                    Toggle("", isOn: $preferences.fullScreenAlerts).labelsHidden()
                }
                RowDivider()
                SettingRow(title: "Lead time", subtitle: "How early to alert before an event starts") {
                    BrandMenu(options: AlertPreferences.allowedLeadMinutes, label: { $0 == 0 ? "At start" : "\($0) min" }, selection: $preferences.leadMinutes)
                }
            }

            SettingsGroup(eyebrow: "System") {
                SettingRow(title: "Check interval", subtitle: "How often to poll your calendars") {
                    BrandMenu(options: [10, 15, 30, 60, 120, 300], label: { $0 < 60 ? "\($0)s" : "\($0 / 60) min" }, selection: $preferences.pollSeconds)
                }
                RowDivider()
                SettingRow(title: "Launch at login", subtitle: "Start Nudgebar when you log in") {
                    Toggle("", isOn: Binding(
                        get: { launchAtLogin },
                        set: { launchAtLogin = $0; LaunchAtLogin.set($0) }
                    )).labelsHidden()
                }
            }
        }
    }
}

// MARK: - Calendars

private struct CalendarsSection: View {
    let model: AppModel
    @ObservedObject var preferences: AlertPreferences
    @ObservedObject var calendarAccess: CalendarAccess

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Calendars", subtitle: "Choose which calendars alert, and override their rules.")

            if !calendarAccess.isAuthorized {
                SettingsGroup(eyebrow: "Access") {
                    SettingRow(title: "Calendar access", subtitle: "Required to read your events") {
                        Button("Grant Access") { model.requestCalendarAccess() }
                            .buttonStyle(.plain).font(Brand.font(12, .semibold)).foregroundStyle(Brand.blush)
                    }
                }
            } else if calendarAccess.calendars.isEmpty {
                Text("No calendars found.").font(Brand.font(13)).foregroundStyle(Brand.stone)
            } else {
                SettingsGroup(eyebrow: "Your calendars") {
                    ForEach(Array(calendarAccess.calendars.enumerated()), id: \.element.id) { index, calendar in
                        if index > 0 { RowDivider() }
                        CalendarRuleRow(calendar: calendar, preferences: preferences)
                    }
                }
            }
        }
    }
}

private struct CalendarRuleRow: View {
    let calendar: CalendarSource
    @ObservedObject var preferences: AlertPreferences
    private static let leadDefault = -1

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { preferences.isCalendarEnabled(id: calendar.id) },
                set: { preferences.setCalendar(id: calendar.id, enabled: $0) }
            )).labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(calendar.title).font(Brand.font(13, .medium)).foregroundStyle(Brand.blush).lineLimit(1)
                Text(calendar.sourceTitle).font(Brand.font(11)).foregroundStyle(Brand.stone).lineLimit(1)
            }
            Spacer()
            BrandMenu(options: [Self.leadDefault] + AlertPreferences.allowedLeadMinutes,
                      label: { $0 == Self.leadDefault ? "Lead: default" : ($0 == 0 ? "At start" : "\($0)m") },
                      selection: leadBinding)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
}

// MARK: - Connectors

private struct ConnectorsSection: View {
    private struct Provider: Identifiable {
        let id: String
        let name: String
        let detail: String
        let symbol: String
        var connected = false
        var beta = false
    }

    private let providers: [Provider] = [
        Provider(id: "eventkit", name: "macOS Calendar", detail: "Local calendars on this Mac", symbol: "calendar", connected: true),
        Provider(id: "google", name: "Google Calendar", detail: "Connect your Google account", symbol: "g.circle"),
        Provider(id: "microsoft", name: "Microsoft Outlook / Exchange", detail: "Microsoft 365 or Exchange Online", symbol: "m.circle"),
        Provider(id: "caldav", name: "CalDAV", detail: "Any standards-based CalDAV server", symbol: "server.rack"),
        Provider(id: "calendly", name: "Calendly", detail: "Scheduled bookings", symbol: "c.circle", beta: true),
        Provider(id: "calcom", name: "Cal.com", detail: "Scheduled bookings", symbol: "c.square", beta: true),
        Provider(id: "acuity", name: "Acuity Scheduling", detail: "Scheduled appointments", symbol: "a.circle", beta: true)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Connectors", subtitle: "Where Nudgebar reads your events.")
            SettingsGroup(eyebrow: "Sources") {
                ForEach(Array(providers.enumerated()), id: \.element.id) { index, provider in
                    if index > 0 { RowDivider() }
                    ConnectorRow(
                        name: provider.name,
                        detail: provider.detail,
                        symbol: provider.symbol,
                        connected: provider.connected,
                        beta: provider.beta
                    )
                }
            }
            Text("Cloud connectors require connecting an account. Local macOS calendars work out of the box via EventKit.")
                .font(Brand.font(11)).foregroundStyle(Brand.stone)
        }
    }
}

private struct ConnectorRow: View {
    let name: String
    let detail: String
    let symbol: String
    let connected: Bool
    let beta: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(Brand.sand)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name).font(Brand.font(13, .medium)).foregroundStyle(Brand.blush)
                    if beta { Badge(text: "BETA", color: Brand.stone) }
                }
                Text(detail).font(Brand.font(11)).foregroundStyle(Brand.stone)
            }
            Spacer()
            if connected {
                Badge(text: "Connected", color: Color(brandHex: 0x57C97A))
            } else {
                Text("Connect").font(Brand.font(12, .semibold)).foregroundStyle(Brand.blush)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

private struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(Brand.font(10, .semibold)).kerning(0.3)
            .foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.16)))
    }
}

// MARK: - Alerts

private struct AlertsSection: View {
    let model: AppModel
    @ObservedObject var preferences: AlertPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Alerts", subtitle: "Sound, auto-dismiss, snooze, and delivery.")

            SettingsGroup(eyebrow: "Auto-dismiss") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Auto-dismiss after").font(Brand.font(13, .medium)).foregroundStyle(Brand.blush)
                        Spacer()
                        Text(autoDismissLabel).font(Brand.font(12, .medium)).foregroundStyle(Brand.sand)
                    }
                    Slider(
                        value: Binding(
                            get: { Double(preferences.autoDismissSeconds == 0 ? 305 : preferences.autoDismissSeconds) },
                            set: { preferences.autoDismissSeconds = $0 >= 302 ? 0 : Int(($0 / 5).rounded()) * 5 }
                        ),
                        in: 5...305
                    )
                    Text("Slide fully right for Never.").font(Brand.font(11)).foregroundStyle(Brand.stone)
                }
                .padding(14)
            }

            SettingsGroup(eyebrow: "Sound") {
                SettingRow(title: "Alert sound") {
                    Button("Preview") { model.previewSound(named: preferences.soundName) }
                        .buttonStyle(.plain).font(Brand.font(12, .semibold)).foregroundStyle(Brand.blush)
                }
                RowDivider()
                FlowChips(items: AlertSoundCatalog.sounds.map(\.name), selected: preferences.soundName) { name in
                    preferences.soundName = name
                    model.previewSound(named: name)
                }
                .padding(14)
            }

            SettingsGroup(eyebrow: "Delivery") {
                SettingRow(title: "Notification fallback", subtitle: "Notify when full-screen is off") {
                    Toggle("", isOn: $preferences.notificationFallbackEnabled).labelsHidden()
                }
                RowDivider()
                SettingRow(title: "Respect Focus", subtitle: "Best-effort; the toggle is the control") {
                    Toggle("", isOn: $preferences.respectFocus).labelsHidden()
                }
            }
        }
    }

    private var autoDismissLabel: String {
        let seconds = preferences.autoDismissSeconds
        if seconds == AlertPreferences.autoDismissNeverSentinel { return "Never" }
        return seconds < 60 ? "\(seconds)s" : "\(seconds / 60) min"
    }
}

private struct FlowChips: View {
    let items: [String]
    let selected: String
    let onTap: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button { onTap(item) } label: {
                    Text(item)
                        .font(Brand.font(12, .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(item == selected ? Brand.blush.opacity(0.18) : Brand.blush.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(item == selected ? Brand.blush.opacity(0.6) : Brand.rule, lineWidth: 1))
                        .foregroundStyle(item == selected ? Brand.blush : Brand.sand)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Shortcuts

private struct ShortcutsSection: View {
    @ObservedObject var preferences: AlertPreferences
    @StateObject private var recorder = ShortcutRecorder()
    @State private var recordingAction: ShortcutAction?
    @State private var conflictMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Shortcuts", subtitle: "Global keyboard shortcuts for alert actions.")
            SettingsGroup(eyebrow: "Bindings") {
                ForEach(Array(ShortcutAction.allCases.enumerated()), id: \.element) { index, action in
                    if index > 0 { RowDivider() }
                    SettingRow(title: action.title) {
                        HStack(spacing: 8) {
                            Text(preferences.shortcut(for: action)?.displayString ?? "Not set")
                                .font(Brand.font(12).monospaced()).foregroundStyle(Brand.sand)
                            Button(recordingAction == action ? "Recording…" : "Record") { beginRecording(action) }
                                .buttonStyle(.plain).font(Brand.font(12, .semibold)).foregroundStyle(Brand.blush)
                                .disabled(recordingAction != nil && recordingAction != action)
                            if preferences.shortcut(for: action) != nil {
                                Button("Clear") { preferences.setShortcut(nil, for: action) }
                                    .buttonStyle(.plain).font(Brand.font(12)).foregroundStyle(Brand.stone)
                            }
                        }
                    }
                }
            }
            if let conflictMessage {
                Text(conflictMessage).font(Brand.font(11)).foregroundStyle(.red)
            }
            Text("Global shortcuts need Accessibility permission; otherwise they work only while Nudgebar is focused.")
                .font(Brand.font(11)).foregroundStyle(Brand.stone)
        }
    }

    private func beginRecording(_ action: ShortcutAction) {
        conflictMessage = nil
        recordingAction = action
        recorder.record { binding in
            if ShortcutBinding.conflicts(binding, in: preferences.shortcuts, excluding: action) {
                conflictMessage = "\(binding.displayString) is already assigned."
            } else {
                preferences.setShortcut(binding, for: action)
            }
            recordingAction = nil
        }
    }
}

// MARK: - About

private struct AboutSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "About", subtitle: "High-visibility calendar reminders for macOS.")
            HStack(spacing: 12) {
                RingLogo(state: .urgent).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Wordmark(size: 20)
                    Text("Version 0.1.0").font(Brand.font(12)).foregroundStyle(Brand.stone)
                }
            }
            Text("Nudgebar shows configurable full-screen reminders before your meetings and events, sourced from your local macOS calendars (with cloud connectors planned).")
                .font(Brand.font(13)).foregroundStyle(Brand.sand)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Launch at login

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Best-effort; requires a proper app bundle.
        }
    }
}
