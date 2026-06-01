import AVFoundation
import Foundation

/// Looping alert tones synthesized in-memory (no bundled audio) and played
/// gaplessly, so an alert sustains instead of firing a one-off ping. Each pattern
/// uses its own instrument timbre (harmonic partials + envelope) and melody.
enum AlarmPattern: String, Hashable, CaseIterable {
    case marimba
    case musicBox
    case kalimba
    case harp
    case glow
    case sunrise
    case doorbell
    case reverie
    case daydream
    case lullaby
    case urgent
}

enum AlarmTone {
    static let sampleRate: Double = 44_100
    private static let attackSeconds: Double = 0.006

    /// A harmonic component: a frequency multiple of the note and its relative level.
    /// Inharmonic multiples (e.g. 2.66) give metallic/bell timbres.
    private struct Partial {
        let multiple: Double
        let amplitude: Double
    }

    private enum Envelope {
        case beep   // flat with tiny edge fades - harsh/urgent
        case pluck  // quick attack, exponential decay - struck/plucked
        case swell  // rises and falls smoothly - soft pad
    }

    /// An instrument voice: timbre (partials), how notes start/stop, and optional
    /// tremolo for life in sustained pads.
    private struct Instrument {
        let partials: [Partial]
        let envelope: Envelope
        let decay: Double          // pluck: decay time = note length * decay
        let tremoloHz: Double
        let tremoloDepth: Double
    }

    /// One slot: frequencies sounding together (a chord); empty list is silence.
    private struct Note {
        let frequencies: [Double]
        let seconds: Double
    }

    private struct Spec {
        let notes: [Note]
        let instrument: Instrument
        let amplitude: Double
    }

    // Musical notes (Hz).
    private static let f4 = 349.23, g4 = 392.00, a4 = 440.00, b4 = 493.88
    private static let c5 = 523.25, d5 = 587.33, e5 = 659.25, f5 = 698.46
    private static let g5 = 783.99, a5 = 880.00, c6 = 1046.50, e6 = 1318.51

    private static func note(_ frequency: Double, _ seconds: Double) -> Note { Note(frequencies: [frequency], seconds: seconds) }
    private static func chord(_ frequencies: [Double], _ seconds: Double) -> Note { Note(frequencies: frequencies, seconds: seconds) }
    private static func rest(_ seconds: Double) -> Note { Note(frequencies: [], seconds: seconds) }

    // MARK: Instruments

    private static let marimbaVoice = Instrument(
        partials: [Partial(multiple: 1, amplitude: 1), Partial(multiple: 3.9, amplitude: 0.4), Partial(multiple: 9.2, amplitude: 0.1)],
        envelope: .pluck, decay: 0.16, tremoloHz: 0, tremoloDepth: 0)
    private static let musicBoxVoice = Instrument(
        partials: [Partial(multiple: 1, amplitude: 1), Partial(multiple: 2, amplitude: 0.55), Partial(multiple: 4, amplitude: 0.28), Partial(multiple: 6, amplitude: 0.12)],
        envelope: .pluck, decay: 0.12, tremoloHz: 0, tremoloDepth: 0)
    private static let kalimbaVoice = Instrument(
        partials: [Partial(multiple: 1, amplitude: 1), Partial(multiple: 2, amplitude: 0.25), Partial(multiple: 3, amplitude: 0.5), Partial(multiple: 4, amplitude: 0.15)],
        envelope: .pluck, decay: 0.2, tremoloHz: 0, tremoloDepth: 0)
    private static let harpVoice = Instrument(
        partials: [Partial(multiple: 1, amplitude: 1), Partial(multiple: 2, amplitude: 0.5), Partial(multiple: 3, amplitude: 0.32), Partial(multiple: 4, amplitude: 0.2), Partial(multiple: 5, amplitude: 0.12), Partial(multiple: 6, amplitude: 0.06)],
        envelope: .pluck, decay: 0.32, tremoloHz: 0, tremoloDepth: 0)
    private static let fluteVoice = Instrument(
        partials: [Partial(multiple: 1, amplitude: 1), Partial(multiple: 2, amplitude: 0.35), Partial(multiple: 3, amplitude: 0.12)],
        envelope: .swell, decay: 0, tremoloHz: 5.5, tremoloDepth: 0.14)
    private static let padVoice = Instrument(
        partials: [Partial(multiple: 1, amplitude: 1), Partial(multiple: 2, amplitude: 0.3), Partial(multiple: 3, amplitude: 0.1)],
        envelope: .swell, decay: 0, tremoloHz: 4, tremoloDepth: 0.12)
    private static let chimeVoice = Instrument(
        partials: [Partial(multiple: 1, amplitude: 1), Partial(multiple: 2, amplitude: 0.6), Partial(multiple: 3, amplitude: 0.25)],
        envelope: .pluck, decay: 0.4, tremoloHz: 0, tremoloDepth: 0)
    private static let beepVoice = Instrument(
        partials: [Partial(multiple: 1, amplitude: 1)], envelope: .beep, decay: 0, tremoloHz: 0, tremoloDepth: 0)

    private static func spec(for pattern: AlarmPattern) -> Spec {
        switch pattern {
        case .marimba:
            return Spec(notes: [note(c5, 0.26), note(e5, 0.26), note(g5, 0.26), note(a5, 0.5), rest(0.7)],
                        instrument: marimbaVoice, amplitude: 0.5)
        case .musicBox:
            return Spec(notes: [note(e5, 0.22), note(c5, 0.22), note(e5, 0.22), note(g5, 0.22), note(c6, 0.4), rest(0.7)],
                        instrument: musicBoxVoice, amplitude: 0.42)
        case .kalimba:
            return Spec(notes: [note(c5, 0.2), note(g5, 0.2), note(e5, 0.2), note(a5, 0.2), note(g5, 0.4), rest(0.7)],
                        instrument: kalimbaVoice, amplitude: 0.46)
        case .harp:
            return Spec(notes: [note(c5, 0.14), note(e5, 0.14), note(g5, 0.14), note(c6, 0.14), note(e6, 0.45), rest(1.0)],
                        instrument: harpVoice, amplitude: 0.42)
        case .glow:
            return Spec(notes: [note(a4, 1.6), note(g4, 1.4), rest(0.5)],
                        instrument: fluteVoice, amplitude: 0.4)
        case .sunrise:
            return Spec(notes: [chord([c5, e5, g5], 2.2), rest(0.6)],
                        instrument: padVoice, amplitude: 0.38)
        case .doorbell:
            return Spec(notes: [note(e5, 0.5), note(c5, 1.0), rest(0.9)],
                        instrument: chimeVoice, amplitude: 0.5)
        case .reverie:
            // Arpeggiated Am - F - C - G progression on harp.
            return Spec(notes: [note(a4, 0.18), note(c5, 0.18), note(e5, 0.18), note(a5, 0.18),
                                note(f4, 0.18), note(a4, 0.18), note(c5, 0.18), note(f5, 0.18),
                                note(c5, 0.18), note(e5, 0.18), note(g5, 0.18), note(c6, 0.18),
                                note(g4, 0.18), note(b4, 0.18), note(d5, 0.18), note(g5, 0.18), rest(0.5)],
                        instrument: harpVoice, amplitude: 0.4)
        case .daydream:
            // Warm pad through a C - G - Am - F progression.
            return Spec(notes: [chord([c5, e5, g5], 1.3), chord([b4, d5, g5], 1.3),
                                chord([a4, c5, e5], 1.3), chord([f4, a4, c5], 1.3), rest(0.4)],
                        instrument: padVoice, amplitude: 0.36)
        case .lullaby:
            // A small music-box melody.
            return Spec(notes: [note(e5, 0.24), note(g5, 0.24), note(c6, 0.36),
                                note(a5, 0.24), note(g5, 0.24), note(e5, 0.36), rest(0.6)],
                        instrument: musicBoxVoice, amplitude: 0.4)
        case .urgent:
            return Spec(notes: [note(1000, 0.12), rest(0.13), note(1000, 0.12), rest(0.13)],
                        instrument: beepVoice, amplitude: 0.6)
        }
    }

    /// One loop cycle of the pattern as a 16-bit mono PCM WAV.
    static func wav(for pattern: AlarmPattern) -> Data {
        let spec = spec(for: pattern)
        var samples: [Int16] = []
        for note in spec.notes {
            samples.append(contentsOf: tone(note, spec: spec))
        }
        return wavData(samples)
    }

    private static func sampleCount(_ seconds: Double) -> Int {
        Int(seconds * sampleRate)
    }

    private static func tone(_ note: Note, spec: Spec) -> [Int16] {
        let count = sampleCount(note.seconds)
        let voices = note.frequencies.filter { $0 > 0 }
        guard !voices.isEmpty else {
            return [Int16](repeating: 0, count: count)
        }

        let instrument = spec.instrument
        let attack = max(1, sampleCount(attackSeconds))
        let partialSum = instrument.partials.reduce(0) { $0 + $1.amplitude }
        let normalize = Double(voices.count) * partialSum
        var out = [Int16]()
        out.reserveCapacity(count)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            var envelope = envelopeValue(instrument.envelope, index: i, count: count, attack: attack, t: t, seconds: note.seconds, decay: instrument.decay)
            if instrument.tremoloHz > 0 {
                envelope *= 1 + instrument.tremoloDepth * sin(2 * .pi * instrument.tremoloHz * t)
            }
            var wave = 0.0
            for frequency in voices {
                for partial in instrument.partials {
                    wave += partial.amplitude * sin(2 * .pi * frequency * partial.multiple * t)
                }
            }
            let value = spec.amplitude * envelope * (wave / normalize)
            out.append(Int16((max(-1, min(1, value)) * 32_767).rounded()))
        }
        return out
    }

    private static func envelopeValue(_ envelope: Envelope, index i: Int, count: Int, attack: Int, t: Double, seconds: Double, decay: Double) -> Double {
        switch envelope {
        case .beep:
            if i < attack { return Double(i) / Double(attack) }
            if i >= count - attack { return Double(count - i) / Double(attack) }
            return 1
        case .pluck:
            let rise = i < attack ? Double(i) / Double(attack) : 1
            return rise * exp(-t / max(0.02, seconds * decay))
        case .swell:
            return sin(.pi * Double(i) / Double(count))
        }
    }

    private static func wavData(_ samples: [Int16]) -> Data {
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let rate = UInt32(sampleRate)
        let blockAlign = channels * bitsPerSample / 8
        let byteRate = rate * UInt32(blockAlign)
        let dataBytes = UInt32(samples.count * 2)

        var data = Data()
        func append32(_ value: UInt32) { var le = value.littleEndian; data.append(Data(bytes: &le, count: 4)) }
        func append16(_ value: UInt16) { var le = value.littleEndian; data.append(Data(bytes: &le, count: 2)) }
        func appendString(_ string: String) { data.append(contentsOf: string.utf8) }

        appendString("RIFF"); append32(36 + dataBytes); appendString("WAVE")
        appendString("fmt "); append32(16); append16(1); append16(channels)
        append32(rate); append32(byteRate); append16(blockAlign); append16(bitsPerSample)
        appendString("data"); append32(dataBytes)
        for sample in samples {
            var le = sample.littleEndian
            data.append(Data(bytes: &le, count: 2))
        }
        return data
    }
}

/// Loops a synthesized alarm tone with `AVAudioPlayer` until stopped.
@MainActor
final class AlarmTonePlayer {
    private var player: AVAudioPlayer?
    private var previewStop: Task<Void, Never>?

    var isPlaying: Bool {
        player?.isPlaying ?? false
    }

    /// Ring continuously until `stop()`.
    func startLooping(data: Data) {
        stop()
        guard let player = try? AVAudioPlayer(data: data) else { return }
        player.numberOfLoops = -1
        player.prepareToPlay()
        player.play()
        self.player = player
    }

    /// Play the alarm for a few seconds (Settings preview), then stop.
    func preview(data: Data, seconds: TimeInterval = 4) {
        startLooping(data: data)
        previewStop = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            // If a newer preview replaced us, this task was cancelled - don't stop it.
            if Task.isCancelled { return }
            self?.stop()
        }
    }

    func stop() {
        previewStop?.cancel()
        previewStop = nil
        player?.stop()
        player = nil
    }
}
