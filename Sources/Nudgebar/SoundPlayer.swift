import AppKit
import Foundation
import os.log

/// Plays the alert sound while an alert window is visible. macOS chimes repeat
/// every 5 seconds; alarm sounds loop continuously via a synthesized tone. Modes:
/// - `start(name:)` while an alert window is visible (loops).
/// - `playOnce(name:)` for the Settings preview button (chimes once, alarms ~3s).
@MainActor
final class SoundPlayer {
    static let loopInterval: TimeInterval = 5
    private static let logger = Logger(subsystem: "com.nudgebar", category: "SoundPlayer")

    private var currentSound: NSSound?
    private var timer: Timer?
    private let resolveSound: (String) -> NSSound?
    private lazy var alarm = AlarmTonePlayer()
    private var alarmActive = false

    init(resolveSound: @escaping (String) -> NSSound? = { NSSound(named: NSSound.Name($0)) }) {
        self.resolveSound = resolveSound
    }

    deinit {
        timer?.invalidate()
        currentSound?.stop()
    }

    var isPlaying: Bool {
        timer != nil || alarmActive
    }

    /// Begin playing `name` and looping until `stop()` is called. Alarm sounds ring
    /// continuously; chimes repeat every 5 seconds. Unresolved sounds stay silent.
    func start(name: String) {
        stop()

        if let data = Self.loopData(named: name) {
            alarm.startLooping(data: data)
            alarmActive = true
            return
        }

        startChimeLoop(name: AlertSoundCatalog.sound(named: name)?.systemName ?? name)
    }

    /// Audio for a continuous sound: a bundled recording, or a synthesized loop.
    private static func loopData(named name: String) -> Data? {
        guard let sound = AlertSoundCatalog.sound(named: name) else { return nil }
        if let fileName = sound.fileName { return fileData(named: fileName) }
        if let pattern = sound.alarmPattern { return AlarmTone.wav(for: pattern) }
        if let pattern = sound.songPattern { return LoopSynth.wav(for: pattern) }
        return nil
    }

    /// Load a bundled audio loop from Resources/Sounds; nil (silent) if missing.
    private static func fileData(named fileName: String) -> Data? {
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        guard let url = Bundle.main.url(forResource: base, withExtension: ext, subdirectory: "Sounds") else {
            logger.warning("Bundled sound \"\(fileName, privacy: .public)\" not found in Resources/Sounds.")
            return nil
        }
        return try? Data(contentsOf: url)
    }

    private func startChimeLoop(name: String) {
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
        if alarmActive {
            alarm.stop()
            alarmActive = false
        }
    }

    /// Preview the named sound: a chime plays once, an alarm rings for a few seconds.
    func playOnce(name: String) {
        if let data = Self.loopData(named: name) {
            stop()
            alarm.preview(data: data)
            alarmActive = true
            return
        }

        let systemName = AlertSoundCatalog.sound(named: name)?.systemName ?? name
        guard let sound = resolveSound(systemName) else {
            Self.logger.warning("NSSound(named:) returned nil for \"\(systemName, privacy: .public)\"; preview is silent.")
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
