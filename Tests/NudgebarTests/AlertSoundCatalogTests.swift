import XCTest
@testable import Nudgebar

final class AlertSoundCatalogTests: XCTestCase {
    func testCatalogIsAllContinuousSounds() {
        let sounds = AlertSoundCatalog.sounds
        XCTAssertFalse(sounds.isEmpty)
        XCTAssertTrue(sounds.allSatisfy { $0.isContinuous }, "every sound should loop continuously now")
    }

    func testEverySoundIsExactlyOneKind() {
        for sound in AlertSoundCatalog.sounds {
            let kinds = [sound.systemName != nil, sound.alarmPattern != nil, sound.songPattern != nil, sound.fileName != nil]
            XCTAssertEqual(kinds.filter { $0 }.count, 1, "\(sound.name) must be exactly one kind of sound")
        }
    }

    func testSoundNamesAreUnique() {
        let names = AlertSoundCatalog.sounds.map(\.name)
        XCTAssertEqual(names.count, Set(names).count, "sound names must be unique")
    }

    @MainActor
    func testDefaultSoundIsInCatalog() {
        XCTAssertNotNil(AlertSoundCatalog.sound(named: AlertPreferences.defaultSoundName))
    }
}
