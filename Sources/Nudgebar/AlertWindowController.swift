import NudgebarCore
import AppKit
import Combine
import SwiftUI

/// One event card inside the alert window. Owns its own auto-dismiss countdown.
@MainActor
final class AlertCardModel: ObservableObject, Identifiable {
    let id: String
    let event: AlertCandidate
    let conference: ConferenceLink?
    let isUrgent: Bool

    /// Initial auto-dismiss duration, or nil when set to Never (drives the ring progress).
    let autoDismissTotal: Int?

    /// Remaining auto-dismiss seconds, or nil when auto-dismiss is set to Never.
    @Published private(set) var remainingSeconds: Int?

    private var task: Task<Void, Never>?
    private let onExpire: (String) -> Void

    init(
        event: AlertCandidate,
        autoDismissSeconds: Int,
        now: Date,
        onExpire: @escaping (String) -> Void
    ) {
        self.id = event.id
        self.event = event
        self.conference = ConferenceLinkResolver.resolve(
            meetingURL: event.meetingURL,
            location: event.location
        )
        self.isUrgent = event.startDate.timeIntervalSince(now) <= StatusItemTitleFormatter.urgentThresholdSeconds
        self.onExpire = onExpire

        if autoDismissSeconds != AlertPreferences.autoDismissNeverSentinel {
            self.autoDismissTotal = autoDismissSeconds
            self.remainingSeconds = autoDismissSeconds
            startCountdown()
        } else {
            self.autoDismissTotal = nil
        }
    }

    private func startCountdown() {
        task = Task { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                guard let self, let remaining = self.remainingSeconds else { return }
                let next = remaining - 1
                self.remainingSeconds = max(0, next)
                if next <= 0 {
                    self.task = nil
                    self.onExpire(self.id)
                    return
                }
            }
        }
    }

    func cancelAutoDismiss() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}

/// The observable card list with the merge / dismiss / snooze rules. Kept free of
/// any `NSWindow` so the behavior is unit-testable.
@MainActor
final class AlertWindowModel: ObservableObject {
    @Published private(set) var cards: [AlertCardModel] = []

    /// Called when the last card is removed (window should close).
    var onEmptied: () -> Void = {}
    /// Called when a card is snoozed: (event, minutes).
    var onSnooze: (AlertCandidate, Int) -> Void = { _, _ in }

    var isEmpty: Bool { cards.isEmpty }

    func add(event: AlertCandidate, autoDismissSeconds: Int, now: Date = .now) {
        guard !cards.contains(where: { $0.id == event.id }) else {
            return
        }
        let card = AlertCardModel(
            event: event,
            autoDismissSeconds: autoDismissSeconds,
            now: now
        ) { [weak self] id in
            self?.dismiss(id: id)
        }
        cards.append(card)
    }

    func dismiss(id: String) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else {
            return
        }
        cards[index].cancelAutoDismiss()
        cards.remove(at: index)
        if cards.isEmpty {
            onEmptied()
        }
    }

    func snooze(id: String, minutes: Int) {
        guard let card = cards.first(where: { $0.id == id }) else {
            return
        }
        onSnooze(card.event, minutes)
        dismiss(id: id)
    }

    func dismissAll() {
        for id in cards.map(\.id) {
            dismiss(id: id)
        }
    }

    func snoozeAll(minutes: Int) {
        let snapshot = cards
        for card in snapshot {
            onSnooze(card.event, minutes)
            card.cancelAutoDismiss()
        }
        cards.removeAll()
        onEmptied()
    }
}

/// Borderless overlay window that can still become key, so it receives keyboard
/// input. Escape dismisses the alert via `onCancel`.
private final class AlertPanelWindow: NSWindow {
    private static let escapeKeyCode: UInt16 = 53

    var onCancel: () -> Void = {}

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == Self.escapeKeyCode {
            onCancel()
        } else {
            super.keyDown(with: event)
        }
    }
}

/// Owns at most one borderless full-screen `NSWindow` and the sound loop bound to
/// its lifecycle. New due events append cards to the same window.
@MainActor
final class AlertWindowController {
    private let model = AlertWindowModel()
    private let sound = SoundPlayer()
    private var window: NSWindow?

    init(onSnooze: @escaping (AlertCandidate, Int) -> Void) {
        model.onSnooze = onSnooze
        model.onEmptied = { [weak self] in self?.closeWindow() }
    }

    func present(event: AlertCandidate, autoDismissSeconds: Int, soundName: String, now: Date = .now) {
        let wasVisible = window != nil
        model.add(event: event, autoDismissSeconds: autoDismissSeconds, now: now)

        guard !wasVisible, !model.isEmpty else {
            return // window already up: the card was appended, sound loop continues uninterrupted
        }
        openWindow()
        sound.start(name: soundName)
    }

    func snoozeAllVisible(minutes: Int) {
        model.snoozeAll(minutes: minutes)
    }

    func dismissAllVisible() {
        model.dismissAll()
    }

    private func openWindow() {
        let screen = NSScreen.main
        let frame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let window = AlertPanelWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isReleasedWhenClosed = false
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = NSHostingView(rootView: AlertOverlayView(model: model))
        window.onCancel = { [weak self] in self?.dismissAllVisible() }

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeWindow() {
        sound.stop()
        window?.orderOut(nil)
        window?.close()
        window = nil
    }
}
