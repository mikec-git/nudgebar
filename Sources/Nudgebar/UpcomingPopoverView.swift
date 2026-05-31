import NudgebarCore
import SwiftUI

/// Hybrid upcoming-events popover: a hero pair of the next one or two events over
/// a compressed timeline of the rest, grouped Today / Tomorrow, with quick controls.
struct UpcomingPopoverView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: AlertPreferences
    @EnvironmentObject private var calendarAccess: CalendarAccess

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.upcomingEvents.isEmpty {
                EmptyStateView(
                    calendarAuthorized: calendarAccess.isAuthorized,
                    onGrantAccess: { model.requestCalendarAccess() }
                )
            } else {
                eventList
            }

            Divider()

            QuickControls(preferences: preferences, model: model)
        }
        .frame(width: 320)
    }

    private var eventList: some View {
        let now = Date()
        let hero = Array(model.upcomingEvents.prefix(2))
        let rest = Array(model.upcomingEvents.dropFirst(2))
        let grouped = UpcomingEventsList.group(rest, now: now)
        let truncated = model.upcomingEvents.count >= UpcomingEventsList.maxEntries

        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(hero) { event in
                    HeroEventCard(
                        event: event,
                        now: now,
                        snoozed: model.snoozeStore.isSnoozed(eventID: event.id, now: now)
                    )
                }

                if !rest.isEmpty {
                    TimelineSection(grouped: grouped, now: now)
                }

                if truncated {
                    Text("Showing the first \(UpcomingEventsList.maxEntries) events")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(12)
        }
        .frame(maxHeight: 360)
    }
}

private struct HeroEventCard: View {
    let event: AlertCandidate
    let now: Date
    let snoozed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(event.startDate.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    LeadPill(seconds: event.startDate.timeIntervalSince(now))
                    if snoozed {
                        Label("Snoozed", systemImage: "zzz")
                            .labelStyle(.iconOnly)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
    }
}

private struct LeadPill: View {
    let seconds: TimeInterval

    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.accentColor.opacity(0.18)))
            .foregroundStyle(Color.accentColor)
    }

    private var label: String {
        if seconds <= 0 {
            return "now"
        }
        let minutes = Int(ceil(seconds / 60))
        if minutes < 60 {
            return "In \(minutes)m"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins == 0 ? "In \(hours)h" : "In \(hours)h \(mins)m"
    }
}

private struct TimelineSection: View {
    let grouped: [UpcomingEventsList.GroupedEvent]
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach([UpcomingEventsList.DayGroup.today, .tomorrow], id: \.rawValue) { day in
                let items = grouped.filter { $0.group == day }
                if !items.isEmpty {
                    Text(day == .today ? "Today" : "Tomorrow")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    ForEach(items) { item in
                        TimelineRow(event: item.event)
                    }
                }
            }
        }
    }
}

private struct TimelineRow: View {
    let event: AlertCandidate

    var body: some View {
        HStack(spacing: 8) {
            Text(event.startDate.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(event.title)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

private struct EmptyStateView: View {
    let calendarAuthorized: Bool
    let onGrantAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All clear")
                .font(.headline)
            Text("No upcoming events")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if !calendarAuthorized {
                Button("Grant Calendar Access", action: onGrantAccess)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
    }
}

private struct QuickControls: View {
    let preferences: AlertPreferences
    let model: AppModel

    var body: some View {
        VStack(spacing: 8) {
            Toggle("Full-screen alerts", isOn: Binding(
                get: { preferences.fullScreenAlerts },
                set: { preferences.fullScreenAlerts = $0 }
            ))

            Picker("Lead time", selection: Binding(
                get: { preferences.leadMinutes },
                set: { preferences.leadMinutes = $0; model.refreshUpcoming() }
            )) {
                ForEach(AlertPreferences.allowedLeadMinutes, id: \.self) { minutes in
                    Text(minutes == 0 ? "At start" : "\(minutes) min").tag(minutes)
                }
            }

            HStack {
                Button("Settings…") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(12)
    }
}
