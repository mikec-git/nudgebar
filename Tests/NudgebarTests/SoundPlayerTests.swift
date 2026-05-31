import AppKit
import XCTest
@testable import Nudgebar

@MainActor
final class SoundPlayerTests: XCTestCase {
    func testStartWithResolvableSoundPlaysUntilStop() throws {
        // NSSound() returns nil at runtime, so use a real system sound for the "playing" path.
        guard let sound = NSSound(named: NSSound.Name("Glass")) else {
            throw XCTSkip("System sound 'Glass' is unavailable in this environment")
        }
        var requested: [String] = []
        let player = SoundPlayer(resolveSound: { name in
            requested.append(name)
            return sound
        })
        player.start(name: "Glass")
        XCTAssertEqual(requested, ["Glass"])
        XCTAssertTrue(player.isPlaying)
        player.stop()
        XCTAssertFalse(player.isPlaying)
    }

    func testStartWithUnresolvableSoundIsSilent() {
        let player = SoundPlayer(resolveSound: { _ in nil })
        player.start(name: "Missing")
        XCTAssertFalse(player.isPlaying)
    }

    func testPlayOnceResolvesNameWithoutLooping() {
        var requested: [String] = []
        let player = SoundPlayer(resolveSound: { name in
            requested.append(name)
            return nil
        })
        player.playOnce(name: "Glass")
        XCTAssertEqual(requested, ["Glass"])
        XCTAssertFalse(player.isPlaying)
    }
}
