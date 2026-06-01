import Foundation

struct AlertSound: Equatable, Hashable, Identifiable {
    let name: String
    let label: String
    /// A macOS system chime played by name, or nil.
    let systemName: String?
    /// An additive-synthesis tone (AlarmTone), or nil.
    let alarmPattern: AlarmPattern?
    /// A multi-voice songlike loop (LoopSynth), or nil.
    let songPattern: SongPattern?
    /// A bundled audio loop in Resources/Sounds (e.g. "rain.m4a"), or nil.
    let fileName: String?

    var isContinuous: Bool { alarmPattern != nil || songPattern != nil || fileName != nil }

    var id: String {
        name
    }
}

enum AlertSoundCatalog {
    static let sounds: [AlertSound] = [
        // Instruments (synth).
        sound("Doorbell", .doorbell),
        sound("Lullaby", .lullaby),
        song("Rhodes", .rhodes),
        // Ambient - real recordings (CC0 / public domain, Wikimedia Commons).
        file("Rain", "rain.m4a"),
        file("Ocean", "ocean.m4a"),
        file("Birds", "birds.m4a"),
        file("Fireplace", "fireplace.m4a"),
        file("Clock", "clock.m4a"),
        file("Airplane", "airplane.m4a"),
        file("Gong", "gong.m4a"),
        // Ambient - synthesized.
        song("Crickets", .crickets),
        song("Droplets", .droplets),
        // Notification tones (Mixkit Free License - commercial OK, no attribution).
        file("Bell", "bell.m4a"),
        file("Happy Bells", "happy_bells.m4a"),
        file("Positive", "positive.m4a"),
        file("Magic Ring", "magic_ring.m4a"),
        file("Guitar", "guitar.m4a"),
        file("Marimba", "marimba.m4a"),
        // Urgent - attention-grabbing.
        sound("Alarm", .urgent)
    ]

    private static func sound(_ name: String, _ pattern: AlarmPattern) -> AlertSound {
        AlertSound(name: name, label: name, systemName: nil, alarmPattern: pattern, songPattern: nil, fileName: nil)
    }

    private static func song(_ name: String, _ pattern: SongPattern) -> AlertSound {
        AlertSound(name: name, label: name, systemName: nil, alarmPattern: nil, songPattern: pattern, fileName: nil)
    }

    /// A bundled audio loop (Resources/Sounds/<fileName>). Used once recordings are added.
    static func file(_ name: String, _ fileName: String) -> AlertSound {
        AlertSound(name: name, label: name, systemName: nil, alarmPattern: nil, songPattern: nil, fileName: fileName)
    }

    static func sound(named name: String) -> AlertSound? {
        sounds.first { $0.name == name }
    }

    static var fallback: AlertSound {
        sounds[0]
    }
}
