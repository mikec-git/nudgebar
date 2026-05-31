import NudgebarCore
import AppKit
import SwiftUI

/// Full-screen overlay: warm translucent backdrop, the Nudgebar wordmark, the
/// merged event cards, and the bulk Snooze All / Dismiss All footer.
struct AlertOverlayView: View {
    @ObservedObject var model: AlertWindowModel

    private var defaultSnoozeMinutes: Int { AlertPreferences.defaultSnoozeMinutes }

    var body: some View {
        ZStack {
            WarmBackdrop().ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 9) {
                        RingLogo(state: .active).frame(width: 22, height: 22)
                        Wordmark(size: 17)
                    }
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 34)

                Spacer(minLength: 12)

                ScrollView {
                    VStack(spacing: 18) {
                        ForEach(model.cards) { card in
                            AlertCardView(
                                card: card,
                                onJoin: { url in NSWorkspace.shared.open(url) },
                                onSnooze: { minutes in model.snooze(id: card.id, minutes: minutes) },
                                onDismiss: { model.dismiss(id: card.id) }
                            )
                        }
                    }
                    .frame(maxWidth: 660)
                    .padding(.horizontal, 40)
                }

                Spacer(minLength: 12)

                if !model.cards.isEmpty {
                    HStack(spacing: 12) {
                        GhostButton(title: "Snooze All") { model.snoozeAll(minutes: defaultSnoozeMinutes) }
                        GhostButton(title: "Dismiss All") { model.dismissAll() }
                    }
                    .padding(.bottom, 36)
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

private struct AlertCardView: View {
    @ObservedObject var card: AlertCardModel
    let onJoin: (URL) -> Void
    let onSnooze: (Int) -> Void
    let onDismiss: () -> Void

    private var calendarColor: Color {
        Color(hexString: card.event.calendarColorHex) ?? Brand.blush
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(calendarColor)
                .frame(width: 4)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(card.event.title)
                            .font(Brand.font(30, .semibold))
                            .foregroundStyle(Brand.blush)
                            .lineLimit(3)
                            .minimumScaleFactor(0.6)

                        metaRow

                        HStack(spacing: 8) {
                            LeadPill(seconds: card.event.startDate.timeIntervalSince(Date()))
                            if let conference = card.conference {
                                ConferenceChip(label: conference.type.label)
                            }
                        }
                    }
                    Spacer(minLength: 16)
                    if let remaining = card.remainingSeconds, let total = card.autoDismissTotal {
                        CountdownRing(remaining: remaining, total: total)
                    }
                }

                HStack(spacing: 10) {
                    if let conference = card.conference {
                        JoinButton { onJoin(conference.url) }
                    }
                    SnoozeMenu(onSnooze: onSnooze)
                    GhostButton(title: "Dismiss", action: onDismiss)
                    Spacer()
                }
            }
            .padding(24)
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Brand.ember)
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(card.isUrgent ? Brand.blush.opacity(0.55) : Brand.rule, lineWidth: card.isUrgent ? 2 : 1))
        )
        .shadow(color: .black.opacity(0.45), radius: 30, y: 16)
    }

    private var metaRow: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(card.event.startDate.formatted(date: .omitted, time: .shortened)) · \(durationLabel)")
                .font(Brand.font(15, .medium))
                .foregroundStyle(Brand.sand)
            HStack(spacing: 14) {
                MetaItem(systemImage: "calendar", text: card.event.calendarTitle, dot: calendarColor)
                if let organizer = card.event.organizer, !organizer.isEmpty {
                    MetaItem(systemImage: "person.crop.circle", text: organizer)
                }
            }
            if let location = card.event.location, !location.isEmpty {
                MetaItem(systemImage: "mappin.and.ellipse", text: location)
            }
        }
    }

    private var durationLabel: String {
        let minutes = Int(card.event.duration / 60)
        if minutes <= 0 { return "now" }
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
    }
}

private struct MetaItem: View {
    let systemImage: String
    let text: String
    var dot: Color?

    var body: some View {
        HStack(spacing: 5) {
            if let dot {
                Circle().fill(dot).frame(width: 8, height: 8)
            } else {
                Image(systemName: systemImage).font(.system(size: 12))
            }
            Text(text).font(Brand.font(13))
        }
        .foregroundStyle(Brand.stone)
        .lineLimit(1)
    }
}

private struct CountdownRing: View {
    let remaining: Int
    let total: Int

    var body: some View {
        ZStack {
            Circle().stroke(Brand.blush.opacity(0.14), lineWidth: 4)
            Circle()
                .trim(from: 0, to: total > 0 ? CGFloat(remaining) / CGFloat(total) : 0)
                .stroke(Brand.blush, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(remaining)s")
                .font(Brand.font(13, .medium).monospacedDigit())
                .foregroundStyle(Brand.sand)
        }
        .frame(width: 56, height: 56)
        .animation(.linear(duration: 0.4), value: remaining)
    }
}

private struct LeadPill: View {
    let seconds: TimeInterval

    var body: some View {
        Text(label)
            .font(Brand.font(12, .semibold))
            .padding(.horizontal, 11)
            .padding(.vertical, 4)
            .background(Capsule().fill(Brand.blush.opacity(0.16)))
            .foregroundStyle(Brand.blush)
    }

    private var label: String {
        if seconds <= 0 { return "Now" }
        let minutes = Int(ceil(seconds / 60))
        return minutes < 60 ? "In \(minutes) min" : "In \(minutes / 60)h \(minutes % 60)m"
    }
}

private struct ConferenceChip: View {
    let label: String

    var body: some View {
        Label(label, systemImage: "video.fill")
            .font(Brand.font(12, .medium))
            .padding(.horizontal, 11)
            .padding(.vertical, 4)
            .background(Capsule().fill(Brand.blush.opacity(0.08)))
            .foregroundStyle(Brand.sand)
    }
}

private struct JoinButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Join", systemImage: "video.fill")
                .font(Brand.font(13, .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Brand.blush))
                .foregroundStyle(Brand.inkDeep)
        }
        .buttonStyle(.plain)
    }
}

private struct SnoozeMenu: View {
    let onSnooze: (Int) -> Void

    var body: some View {
        Menu {
            ForEach(AlertPreferences.snoozePresetMinutes, id: \.self) { minutes in
                Button("\(minutes) min") { onSnooze(minutes) }
            }
        } label: {
            Label("Snooze", systemImage: "zzz")
                .font(Brand.font(13, .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .background(Capsule().fill(Brand.blush.opacity(0.10)))
        .overlay(Capsule().strokeBorder(Brand.ruleStrong, lineWidth: 1))
        .foregroundStyle(Brand.sand)
    }
}

private struct GhostButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Brand.font(13, .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Brand.blush.opacity(0.06)))
                .overlay(Capsule().strokeBorder(Brand.ruleStrong, lineWidth: 1))
                .foregroundStyle(Brand.sand)
        }
        .buttonStyle(.plain)
    }
}

/// Warm copper-toned translucent backdrop with a faint blush edge halo.
private struct WarmBackdrop: View {
    var body: some View {
        ZStack {
            VisualEffectBackdrop()
            Brand.inkDeep.opacity(0.66)
            RadialGradient(
                colors: [Brand.blush.opacity(0.10), .clear],
                center: .center,
                startRadius: 200,
                endRadius: 900
            )
            .blendMode(.plusLighter)
        }
    }
}

private struct VisualEffectBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

extension Color {
    init?(hexString: String?) {
        guard var hex = hexString else { return nil }
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }
}
