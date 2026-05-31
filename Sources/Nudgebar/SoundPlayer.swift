import AppKit
import Foundation
import os.log

/// Plays a macOS system sound once and optionally loops it every 5 seconds while running.
/// Used in two modes:
/// - `start(name:)` while an alert window is visible (5s loop).
/// - `playOnce(name:)` for the Settings preview button (no loop).
@MainActor
final class SoundPlayer {
    static let loopInterval: TimeInterval = 5
    private static let logger = Logger(subsystem: "com.nudgebar", category: "SoundPlayer")

    private var currentSound: NSSound?
    private var timer: Timer?
    private let resolveSound: (String) -> NSSound?

    init(resolveSound: @escaping (String) -> NSSound? = { NSSound(named: NSSound.Name($0)) }) {
        self.resolveSound = resolveSound
    }

    deinit {
        timer?.invalidate()
        currentSound?.stop()
    }

    var isPlaying: Bool {
        timer != nil
    }

    /// Begin playing `name` once immediately and repeating every 5 seconds until `stop()` is called.
    /// If the named sound cannot be resolved, log and proceed silently.
    func start(name: String) {
        stop()

        guard let sound = resolveSound(name) else {
            Self.logger.warning("NSSound(named:) returned nil for \"\(name, privacy: .public)\"; proceeding silently.")
            return
        }

        currentSound = sound
        sound.play()

        let timer = Timer.scheduledTimer(withTimeInterval: Self.loopInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        timer.tolerance = Self.loopInterval * 0.05
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        currentSound?.stop()
        currentSound = nil
    }

    /// Play the named sound exactly once (no loop). Used by the Settings preview.
    func playOnce(name: String) {
        guard let sound = resolveSound(name) else {
            Self.logger.warning("NSSound(named:) returned nil for \"\(name, privacy: .public)\"; preview is silent.")
            return
        }
        sound.play()
    }

    private func tick() {
        guard let sound = currentSound else {
            return
        }
        sound.stop()
        sound.play()
    }
}
