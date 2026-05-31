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
        case .connectors: ConnectorsSection(model: model, connectorStore: model.connectorStore)
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
    @ObservedObject var model: AppModel
    @ObservedObject var connectorStore: ConnectorStore

    private let providers: [ProviderID] = [.eventKit, .googleCalendar, .microsoftGraph, .calDAV, .calendly, .calCom, .acuity]
    private let implemented: Set<ProviderID> = [.eventKit, .googleCalendar, .microsoftGraph, .calendly, .calCom, .acuity, .calDAV]
    private let oauthProviders: Set<ProviderID> = [.googleCalendar, .microsoftGraph, .calendly]
    @State private var credentialProvider: ProviderID?
    @State private var oauthSetupProvider: ProviderID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Connectors", subtitle: "Where Nudgebar reads your events.")
            SettingsGroup(eyebrow: "Sources") {
                ForEach(Array(providers.enumerated()), id: \.element) { index, provider in
                    if index > 0 { RowDivider() }
                    row(provider)
                }
            }
            if let error = model.connectError {
                Text(error).font(Brand.font(11)).foregroundStyle(.red).padding(.bottom, 8)
            }
            Text("Add OAuth client IDs to \(ConnectorConfig.fileURL.path) to enable cloud connectors. Local calendars work via EventKit.")
                .font(Brand.font(11)).foregroundStyle(Brand.stone)
        }
        .sheet(item: $credentialProvider) { provider in
            CredentialEntrySheet(
                provider: provider,
                fields: model.credentialFields(for: provider),
                onSubmit: { values in
                    model.connectWithCredentials(providerID: provider, values: values)
                    credentialProvider = nil
                },
                onCancel: { credentialProvider = nil }
            )
        }
        .sheet(item: $oauthSetupProvider) { provider in
            OAuthSetupSheet(provider: provider, model: model, onClose: { oauthSetupProvider = nil })
        }
    }

    @ViewBuilder
    private func row(_ provider: ProviderID) -> some View {
        let connected = provider == .eventKit || connectorStore.account(for: provider) != nil
        let beta = [ProviderID.calendly, .calCom, .acuity].contains(provider)
        HStack(spacing: 12) {
            Image(systemName: symbol(provider)).font(.system(size: 18)).foregroundStyle(Brand.sand).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(provider.displayName).font(Brand.font(13, .medium)).foregroundStyle(Brand.blush)
                    if beta { Badge(text: "BETA", color: Brand.stone) }
                }
                Text(detail(provider)).font(Brand.font(11)).foregroundStyle(Brand.stone)
            }
            Spacer()
            trailing(provider, connected: connected)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    @ViewBuilder
    private func trailing(_ provider: ProviderID, connected: Bool) -> some View {
        if provider == .eventKit {
            Badge(text: "Connected", color: Color(brandHex: 0x57C97A))
        } else if connected {
            HStack(spacing: 8) {
                Badge(text: "Connected", color: Color(brandHex: 0x57C97A))
                Button("Disconnect") { model.disconnect(providerID: provider) }
                    .buttonStyle(.plain).font(Brand.font(12, .medium)).foregroundStyle(Brand.stone)
            }
        } else if !implemented.contains(provider) {
            Text("Coming soon").font(Brand.font(12)).foregroundStyle(Brand.stone)
        } else if oauthProviders.contains(provider) {
            if ConnectorConfig.isConfigured(provider) {
                HStack(spacing: 8) {
                    Button("Connect") { model.connect(providerID: provider) }
                        .buttonStyle(.plain).font(Brand.font(12, .semibold)).foregroundStyle(Brand.blush)
                    Button("Edit") { oauthSetupProvider = provider }
                        .buttonStyle(.plain).font(Brand.font(12)).foregroundStyle(Brand.stone)
                }
            } else {
                Button("Set up") { oauthSetupProvider = provider }
                    .buttonStyle(.plain).font(Brand.font(12, .semibold)).foregroundStyle(Brand.blush)
            }
        } else {
            Button("Connect") { credentialProvider = provider }
                .buttonStyle(.plain).font(Brand.font(12, .semibold)).foregroundStyle(Brand.blush)
        }
    }

    private func symbol(_ provider: ProviderID) -> String {
        switch provider {
        case .eventKit: "calendar"
        case .googleCalendar: "g.circle"
        case .microsoftGraph: "m.circle"
        case .calDAV: "server.rack"
        case .calendly: "c.circle"
        case .calCom: "c.square"
        case .acuity: "a.circle"
        }
    }

    private func detail(_ provider: ProviderID) -> String {
        switch provider {
        case .eventKit: "Local calendars on this Mac"
        case .googleCalendar: "Connect your Google account"
        case .microsoftGraph: "Microsoft 365 or Exchange"
        case .calDAV: "Standards-based CalDAV server"
        case .calendly: "Scheduled bookings"
        case .calCom: "Scheduled bookings"
        case .acuity: "Scheduled appointments"
        }
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

// MARK: - OAuth setup

private struct OAuthSetupSheet: View {
    let provider: ProviderID
    let model: AppModel
    let onClose: () -> Void
    @State private var clientID = ""
    @State private var clientSecret = ""

    private var needsSecret: Bool { provider == .calendly }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Set up \(provider.displayName)")
                .font(Brand.font(16, .semibold)).foregroundStyle(Brand.blush)
            Text(instructions)
                .font(Brand.font(11)).foregroundStyle(Brand.sand)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("Redirect URI").font(Brand.font(10, .semibold)).foregroundStyle(Brand.stone)
                Text(ConnectorConfig.redirectHint(for: provider))
                    .font(Brand.font(11).monospaced()).foregroundStyle(Brand.blush)
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Client ID").font(Brand.font(11)).foregroundStyle(Brand.stone)
                TextField("Client ID", text: $clientID).textFieldStyle(.roundedBorder)
            }
            if needsSecret {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Client secret").font(Brand.font(11)).foregroundStyle(Brand.stone)
                    SecureField("Client secret", text: $clientSecret).textFieldStyle(.roundedBorder)
                }
            }

            HStack {
                if let url = consoleURL {
                    Link("Open console", destination: url).font(Brand.font(12)).tint(Brand.blush)
                }
                Spacer()
                Button("Cancel", action: onClose).buttonStyle(.plain).foregroundStyle(Brand.stone)
                Button("Save") {
                    model.saveOAuthClient(
                        providerID: provider,
                        clientID: clientID.trimmingCharacters(in: .whitespacesAndNewlines),
                        clientSecret: clientSecret
                    )
                    onClose()
                }
                .buttonStyle(.borderedProminent).tint(Brand.blush)
                .disabled(clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20).frame(width: 460)
        .background(Brand.ink).environment(\.colorScheme, .dark)
        .onAppear {
            let config = ConnectorConfig.load()
            clientID = config.oauthClientID(for: provider) ?? ""
            clientSecret = config.oauthClientSecret(for: provider) ?? ""
        }
    }

    private var instructions: String {
        switch provider {
        case .googleCalendar:
            return "In Google Cloud Console: enable the Google Calendar API, then create an OAuth 2.0 Client ID of type \"iOS\" (any bundle ID, e.g. com.local.Nudgebar). Paste the client ID below — Nudgebar derives the redirect automatically. iOS clients have no secret."
        case .microsoftGraph:
            return "In Azure Portal → App registrations: create an app, add a \"Mobile and desktop applications\" platform with the redirect URI below, and grant Microsoft Graph delegated Calendars.Read. Paste the Application (client) ID."
        case .calendly:
            return "In the Calendly developer portal: create an OAuth app with the redirect URI below, then paste its client ID and secret."
        default:
            return ""
        }
    }

    private var consoleURL: URL? {
        switch provider {
        case .googleCalendar: return URL(string: "https://console.cloud.google.com/apis/credentials")
        case .microsoftGraph: return URL(string: "https://portal.azure.com/")
        case .calendly: return URL(string: "https://developer.calendly.com/")
        default: return nil
        }
    }
}

// MARK: - Credential entry

private struct CredentialEntrySheet: View {
    let provider: ProviderID
    let fields: [ConnectorCredentialField]
    let onSubmit: ([String: String]) -> Void
    let onCancel: () -> Void
    @State private var values: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connect \(provider.displayName)")
                .font(Brand.font(16, .semibold)).foregroundStyle(Brand.blush)
            ForEach(fields) { field in
                VStack(alignment: .leading, spacing: 4) {
                    Text(field.label).font(Brand.font(11)).foregroundStyle(Brand.stone)
                    Group {
                        if field.isSecret {
                            SecureField(field.label, text: binding(field.key))
                        } else {
                            TextField(field.label, text: binding(field.key))
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                }
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).buttonStyle(.plain).foregroundStyle(Brand.stone)
                Button("Connect") { onSubmit(values) }.buttonStyle(.borderedProminent).tint(Brand.blush)
            }
        }
        .padding(20)
        .frame(width: 380)
        .background(Brand.ink)
        .environment(\.colorScheme, .dark)
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
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
