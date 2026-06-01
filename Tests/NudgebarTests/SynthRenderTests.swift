import XCTest
@testable import Nudgebar

/// Deterministic checks that every synthesized sound renders a valid, non-empty
/// WAV (no audio hardware required).
final class SynthRenderTests: XCTestCase {
    private let riff = Data("RIFF".utf8)

    func testEverySongRendersValidWav() {
        for pattern in SongPattern.allCases {
            let data = LoopSynth.wav(for: pattern)
            XCTAssertGreaterThan(data.count, 44, "\(pattern) should render PCM beyond the 44-byte header")
            XCTAssertEqual(data.prefix(4), riff, "\(pattern) should be a RIFF/WAV")
        }
    }

    func testEveryAlarmToneRendersValidWav() {
        for pattern in AlarmPattern.allCases {
            let data = AlarmTone.wav(for: pattern)
            XCTAssertGreaterThan(data.count, 44, "\(pattern) should render PCM beyond the 44-byte header")
            XCTAssertEqual(data.prefix(4), riff, "\(pattern) should be a RIFF/WAV")
        }
    }
}
