import Foundation

struct AlertSound: Equatable, Hashable, Identifiable {
    let name: String
    let label: String

    var id: String {
        name
    }
}

enum AlertSoundCatalog {
    static let sounds: [AlertSound] = [
        AlertSound(name: "Glass", label: "Glass"),
        AlertSound(name: "Ping", label: "Ping"),
        AlertSound(name: "Submarine", label: "Submarine"),
        AlertSound(name: "Funk", label: "Funk"),
        AlertSound(name: "Blow", label: "Blow"),
        AlertSound(name: "Hero", label: "Hero"),
        AlertSound(name: "Pop", label: "Pop"),
        AlertSound(name: "Tink", label: "Tink")
    ]

    static func sound(named name: String) -> AlertSound? {
        sounds.first { $0.name == name }
    }

    static var fallback: AlertSound {
        sounds[0]
    }
}
