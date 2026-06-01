import NudgebarCore
import SwiftUI

/// Hybrid upcoming-events popover in the Nudgebar brand: a hero pair of the next
/// one or two events over a compressed Today / Tomorrow timeline.
struct UpcomingPopoverView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var preferences: AlertPreferences
    @EnvironmentObject private var calendarAccess: CalendarAccess

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if model.upcomingEvents.isEmpty {
                emptyState
            } else {
                eventList
            }

            Divider().overlay(Brand.rule)
            QuickControls(preferences: preferences, model: model)
        }
        .frame(width: 340)
        .background(Brand.ink)
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(spacing: 9) {
            RingLogo(state: .active).frame(width: 18, height: 18)
            Wordmark(size: 15)
            Spacer()
            Text("Today · Tomorrow")
                .font(Brand.font(11, .medium))
                .foregroundStyle(Brand.stone)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var eventList: some View {
        let now = Date()
        let hero = Array(model.upcomingEvents.prefix(2))
        let rest = Array(model.upcomingEvents.dropFirst(2))
        let grouped = UpcomingEventsList.group(rest, now: now)
        let truncated = model.upcomingEvents.count >= UpcomingEventsList.maxEntries

        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(hero) { event in
                    HeroCard(
                        event: event,
                        now: now,
                        snoozed: model.snoozeStore.isSnoozed(eventID: event.id, now: now),
                        onJoin: { url in NSWorkspace.shared.open(url) }
                    )
                }

                if !rest.isEmpty {
                    TimelineSection(grouped: grouped)
                }

                if truncated {
                    Text("Showing the first \(UpcomingEventsList.maxEntries) events")
                        .font(Brand.font(11))
                        .foregroundStyle(Brand.stone)
                        .padding(.top, 2)
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 380)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            RingLogo(state: .idle).frame(width: 26, height: 26)
            Text("All clear")
                .font(Brand.font(17, .semibold))
                .foregroundStyle(Brand.blush)
            Text("No upcoming events")
                .font(Brand.font(13))
                .foregroundStyle(Brand.sand)
            if !calendarAccess.isAuthorized {
                Button("Grant Calendar Access") { model.requestCalendarAccess() }
                    .buttonStyle(.plain)
                    .font(Brand.font(13, .semibold))
                    .foregroundStyle(Brand.blush)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
    }
}

private struct HeroCard: View {
    let event: AlertCandidate
    let now: Date
    let snoozed: Bool
    let onJoin: (URL) -> Void

    private var calendarColor: Color { Color(hexString: event.calendarColorHex) ?? Brand.blush }
    private var conference: ConferenceLink? {
        ConferenceLinkResolver.resolve(meetingURL: event.meetingURL, location: event.location)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2).fill(calendarColor).frame(width: 3).padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle().fill(calendarColor).frame(width: 7, height: 7)
                    Text(event.calendarTitle).font(Brand.font(11, .medium)).foregroundStyle(Brand.stone).lineLimit(1)
                    if snoozed {
                        Image(systemName: "zzz").font(.system(size: 10)).foregroundStyle(Brand.stone)
                    }
                    Spacer()
                    Text(event.isAllDay ? "All day" : event.startDate.formatted(date: .omitted, time: .shortened))
                        .font(Brand.font(12, .medium)).foregroundStyle(Brand.sand)
                }

                Text(event.title).font(Brand.font(15, .semibold)).foregroundStyle(Brand.blush).lineLimit(2)

                HStack(spacing: 8) {
                    if !event.isAllDay {
                        LeadPillSmall(seconds: event.startDate.timeIntervalSince(now))
                    }
                    if let location = event.location, !location.isEmpty, conference == nil {
                        Text(location).font(Brand.font(11)).foregroundStyle(Brand.stone).lineLimit(1)
                    }
                    Spacer()
                    if let conference {
                        Button { onJoin(conference.url) } label: {
                            Text("Join").font(Brand.font(12, .semibold))
                                .padding(.horizontal, 12).padding(.vertical, 4)
                                .background(Capsule().fill(Brand.blush))
                                .foregroundStyle(Brand.inkDeep)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.leading, 11)
            .padding(.vertical, 11)
            .padding(.trailing, 12)
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Brand.ember))
    }
}

private struct LeadPillSmall: View {
    let seconds: TimeInterval

    var body: some View {
        Text(label)
            .font(Brand.font(11, .semibold))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(Capsule().fill(Brand.blush.opacity(0.16)))
            .foregroundStyle(Brand.blush)
    }

    private var label: String {
        if seconds <= 0 { return "Now" }
        let minutes = Int(ceil(seconds / 60))
        return minutes < 60 ? "In \(minutes)m" : "In \(minutes / 60)h \(minutes % 60)m"
    }
}

private struct TimelineSection: View {
    let grouped: [UpcomingEventsList.GroupedEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach([UpcomingEventsList.DayGroup.today, .tomorrow], id: \.rawValue) { day in
                let items = grouped.filter { $0.group == day }
                if !items.isEmpty {
                    Text(day == .today ? "TODAY" : "TOMORROW")
                        .font(Brand.font(10, .semibold))
                        .kerning(0.6)
                        .foregroundStyle(Brand.stone)
                        .padding(.top, 8)
                        .padding(.bottom, 2)
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
    private var calendarColor: Color { Color(hexString: event.calendarColorHex) ?? Brand.sand }

    var body: some View {
        HStack(spacing: 9) {
            Text(event.isAllDay ? "All day" : event.startDate.formatted(date: .omitted, time: .shortened))
                .font(Brand.font(12).monospacedDigit())
                .foregroundStyle(Brand.sand)
                .frame(width: 62, alignment: .leading)
            Circle().fill(calendarColor).frame(width: 6, height: 6)
            Text(event.title).font(Brand.font(12)).foregroundStyle(Brand.sand).lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }
}

private struct QuickControls: View {
    @ObservedObject var preferences: AlertPreferences
    let model: AppModel

    var body: some View {
        VStack(spacing: 10) {
            Toggle("Full-screen alerts", isOn: $preferences.fullScreenAlerts)
                .font(Brand.font(13))
                .tint(Brand.blush)
                .foregroundStyle(Brand.sand)

            HStack {
                Text("Lead time").font(Brand.font(13)).foregroundStyle(Brand.sand)
                Spacer()
                HStack(spacing: 14) {
                    Button { adjustLead(by: -1) } label: {
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain).foregroundStyle(Brand.blush)
                    .disabled(preferences.leadMinutes == AlertPreferences.allowedLeadMinutes.first)

                    Text(preferences.leadMinutes == 0 ? "At start" : "\(preferences.leadMinutes) min")
                        .font(Brand.font(12, .medium)).foregroundStyle(Brand.blush)
                        .frame(minWidth: 56)

                    Button { adjustLead(by: 1) } label: {
                        Image(systemName: "chevron.up").font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain).foregroundStyle(Brand.blush)
                    .disabled(preferences.leadMinutes == AlertPreferences.allowedLeadMinutes.last)
                }
            }

            HStack {
                Button("Settings…") { model.openSettingsAction?() }
                    .buttonStyle(.plain).font(Brand.font(13)).foregroundStyle(Brand.sand)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain).font(Brand.font(13)).foregroundStyle(Brand.stone)
            }
        }
        .padding(16)
    }

    private func adjustLead(by delta: Int) {
        let options = AlertPreferences.allowedLeadMinutes
        let index = options.firstIndex(of: preferences.leadMinutes) ?? 0
        let next = min(max(index + delta, 0), options.count - 1)
        preferences.leadMinutes = options[next]
        model.refreshUpcoming()
    }
}
