import NudgebarCore
import AppKit
import SwiftUI

/// Full-screen overlay: a warm translucent backdrop with the merged event cards
/// and the bulk Snooze All / Dismiss All footer.
struct AlertOverlayView: View {
    @ObservedObject var model: AlertWindowModel

    private var defaultSnoozeMinutes: Int {
        let presets = AlertPreferences.snoozePresetMinutes
        return presets.count > 1 ? presets[1] : (presets.first ?? 5)
    }

    var body: some View {
        ZStack {
            WarmBackdrop().ignoresSafeArea()

            VStack(spacing: 24) {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(model.cards) { card in
                            AlertCardView(
                                card: card,
                                onJoin: { url in NSWorkspace.shared.open(url) },
                                onSnooze: { minutes in model.snooze(id: card.id, minutes: minutes) },
                                onDismiss: { model.dismiss(id: card.id) }
                            )
                        }
                    }
                    .frame(maxWidth: 640)
                    .padding(40)
                }

                if !model.cards.isEmpty {
                    HStack(spacing: 16) {
                        Button("Snooze All") { model.snoozeAll(minutes: defaultSnoozeMinutes) }
                        Button("Dismiss All") { model.dismissAll() }
                            .keyboardShortcut(.cancelAction)
                    }
                    .controlSize(.large)
                    .padding(.bottom, 32)
                }
            }
        }
    }
}

private struct AlertCardView: View {
    @ObservedObject var card: AlertCardModel
    let onJoin: (URL) -> Void
    let onSnooze: (Int) -> Void
    let onDismiss: () -> Void

    private var calendarColor: Color {
        Color(hexString: card.event.calendarColorHex) ?? .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Circle().fill(calendarColor).frame(width: 11, height: 11)
                Text(card.event.calendarTitle)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                if let remaining = card.remainingSeconds {
                    CountdownBadge(seconds: remaining)
                }
            }

            Text(card.event.title)
                .font(.system(size: 40, weight: .bold))
                .lineLimit(3)
                .minimumScaleFactor(0.6)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(card.event.startDate.formatted(date: .omitted, time: .shortened)) · \(durationLabel)")
                    .font(.title3)
                if let organizer = card.event.organizer, !organizer.isEmpty {
                    Label(organizer, systemImage: "person.crop.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                if let location = card.event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                LeadPillLarge(seconds: card.event.startDate.timeIntervalSince(Date()))
                if let conference = card.conference {
                    ConferenceChip(label: conference.type.label)
                }
            }

            HStack(spacing: 12) {
                if let conference = card.conference {
                    Button { onJoin(conference.url) } label: {
                        Label("Join", systemImage: "video.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Menu {
                    ForEach(AlertPreferences.snoozePresetMinutes, id: \.self) { minutes in
                        Button("\(minutes) min") { onSnooze(minutes) }
                    }
                } label: {
                    Label("Snooze", systemImage: "zzz")
                }
                .frame(maxWidth: 130)

                Button("Dismiss", action: onDismiss)
                Spacer()
            }
            .controlSize(.large)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(card.isUrgent ? Color.orange.opacity(0.9) : Color.clear, lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
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

private struct LeadPillLarge: View {
    let seconds: TimeInterval

    var body: some View {
        Text(label)
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.accentColor.opacity(0.20)))
            .foregroundStyle(Color.accentColor)
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
        Label(label, systemImage: "video")
            .font(.callout.weight(.medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
    }
}

private struct CountdownBadge: View {
    let seconds: Int

    var body: some View {
        Label("\(seconds)s", systemImage: "timer")
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
    }
}

/// Warm copper-toned translucent backdrop: a behind-window blur tinted toward the
/// brand ember so the desktop reads faintly while card text stays at AA contrast.
private struct WarmBackdrop: View {
    var body: some View {
        ZStack {
            VisualEffectBackdrop()
            Color(red: 0.176, green: 0.145, blue: 0.125).opacity(0.62)
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
