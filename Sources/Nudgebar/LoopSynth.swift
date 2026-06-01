import Foundation

/// Songlike loops built from a small multi-voice synth: different oscillators
/// (square/saw/triangle/noise), 2-operator FM, a lowpass-filter sweep, and
/// timeline mixing (bass + melody + drums together). Genuinely different timbres
/// from the additive `AlarmTone` voices.
enum SongPattern: String, Hashable, CaseIterable {
    case rhodes
    case groove
    case crickets
    case droplets
    case windChimes
    case vibraphone
}

private enum Wave {
    case sine, triangle, square, saw, noise
}

private struct SynthVoice {
    var wave: Wave = .sine
    var fmRatio: Double = 0       // modulator/carrier ratio; 0 disables FM
    var fmIndex: Double = 0       // FM depth (scaled by the amp envelope)
    var attack: Double = 0.004
    var decay: Double = 0.25      // time constant toward `sustain`
    var sustain: Double = 0       // 0 = pluck (decays to silence)
    var release: Double = 0.06
    var cutoffStart: Double = 0   // lowpass sweep start (Hz); 0 bypasses the filter
    var cutoffEnd: Double = 0
    var cutoffTime: Double = 0.3
    var pulseWidth: Double = 0.5
    var gain: Double = 1
    var bend: Double = 1          // end/start frequency ratio (exponential pitch glide)
    var tremoloHz: Double = 0     // amplitude wobble (vibraphone shimmer); 0 disables
    var tremoloDepth: Double = 0
}

/// Tiny seeded PRNG for deterministic scattering of ambient events.
private struct Rand {
    var state: UInt64
    mutating func unit() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
    mutating func range(_ low: Double, _ high: Double) -> Double { low + (high - low) * unit() }
}

private struct SynthEvent {
    let start: Double
    let duration: Double
    let freqs: [Double]
    let voice: SynthVoice
}

enum LoopSynth {
    static let sampleRate: Double = 44_100

    static func wav(for pattern: SongPattern) -> Data {
        let song = song(for: pattern)
        return wavData(render(seconds: song.seconds, events: song.events))
    }

    // MARK: Rendering

    private static func render(seconds: Double, events: [SynthEvent]) -> [Int16] {
        var buffer = [Double](repeating: 0, count: Int(seconds * sampleRate))
        for event in events {
            for freq in event.freqs {
                renderNote(into: &buffer, start: event.start, duration: event.duration, freq: freq, voice: event.voice)
            }
        }
        let peak = buffer.reduce(0) { Swift.max($0, abs($1)) }
        let scale = peak > 0 ? 0.92 / peak : 1
        return buffer.map { Int16((Swift.max(-1, Swift.min(1, $0 * scale)) * 32_767).rounded()) }
    }

    private static func renderNote(into buffer: inout [Double], start: Double, duration: Double, freq: Double, voice: SynthVoice) {
        let startIndex = Int(start * sampleRate)
        let total = Int((duration + voice.release + 0.02) * sampleRate)
        let baseInc = 2 * .pi * freq / sampleRate
        let baseModInc = baseInc * voice.fmRatio
        var phase = 0.0
        var modPhase = 0.0
        var lowpass = 0.0
        var rng: UInt64 = 0x2545F4914F6CDD1D

        for i in 0..<total {
            let index = startIndex + i
            if index < 0 { continue }
            if index >= buffer.count { break }
            let t = Double(i) / sampleRate
            var amp = envelope(t: t, duration: duration, voice: voice)
            if voice.tremoloHz > 0 {
                amp *= 1 + voice.tremoloDepth * sin(2 * .pi * voice.tremoloHz * t)
            }

            var sample: Double
            if voice.fmIndex > 0 {
                sample = sin(phase + voice.fmIndex * amp * sin(modPhase))
            } else {
                switch voice.wave {
                case .sine:
                    sample = sin(phase)
                case .triangle:
                    sample = 2 / .pi * asin(sin(phase))
                case .square:
                    sample = phase.truncatingRemainder(dividingBy: 2 * .pi) < 2 * .pi * voice.pulseWidth ? 1 : -1
                case .saw:
                    let p = phase / (2 * .pi)
                    sample = 2 * (p - floor(p + 0.5))
                case .noise:
                    rng = rng &* 6364136223846793005 &+ 1442695040888963407
                    sample = Double(Int64(bitPattern: rng)) / Double(Int64.max)
                }
            }

            if voice.cutoffStart > 0 {
                let frac = Swift.min(1, t / Swift.max(0.02, voice.cutoffTime))
                let cutoff = voice.cutoffStart + (voice.cutoffEnd - voice.cutoffStart) * frac
                let rc = 1 / (2 * .pi * cutoff)
                let coeff = (1 / sampleRate) / (rc + 1 / sampleRate)
                lowpass += coeff * (sample - lowpass)
                sample = lowpass
            }

            buffer[index] += sample * amp * voice.gain
            if voice.bend == 1 {
                phase += baseInc
                modPhase += baseModInc
            } else {
                let glide = pow(voice.bend, Swift.min(1, t / Swift.max(0.001, duration)))
                phase += baseInc * glide
                modPhase += baseModInc * glide
            }
        }
    }

    private static func envelope(t: Double, duration: Double, voice: SynthVoice) -> Double {
        if t < voice.attack { return t / voice.attack }
        let afterAttack = t - voice.attack
        if voice.sustain <= 0 {
            return exp(-afterAttack / Swift.max(0.02, voice.decay))
        }
        if t < duration {
            let decayed = exp(-afterAttack / Swift.max(0.02, voice.decay))
            return voice.sustain + (1 - voice.sustain) * decayed
        }
        return voice.sustain * exp(-(t - duration) / Swift.max(0.02, voice.release))
    }

    // MARK: Composition helpers

    private static func hz(_ midi: Int) -> Double { 440 * pow(2, Double(midi - 69) / 12) }

    private static func melody(_ voice: SynthVoice, beat: Double, gate: Double = 0.9, from start: Double = 0, _ midis: [Int?]) -> [SynthEvent] {
        var events: [SynthEvent] = []
        for (i, midi) in midis.enumerated() {
            guard let midi else { continue }
            events.append(SynthEvent(start: start + Double(i) * beat, duration: beat * gate, freqs: [hz(midi)], voice: voice))
        }
        return events
    }

    private static func chords(_ voice: SynthVoice, each seconds: Double, gate: Double = 0.95, _ chords: [[Int]]) -> [SynthEvent] {
        var events: [SynthEvent] = []
        for (i, chord) in chords.enumerated() {
            events.append(SynthEvent(start: Double(i) * seconds, duration: seconds * gate, freqs: chord.map(hz), voice: voice))
        }
        return events
    }

    // MARK: Songs

    private struct Song { let seconds: Double; let events: [SynthEvent] }

    private static func song(for pattern: SongPattern) -> Song {
        switch pattern {
        case .rhodes:
            let rhodes = SynthVoice(fmRatio: 1, fmIndex: 2.6, attack: 0.006, decay: 0.5, sustain: 0.32, release: 0.4, gain: 0.55)
            let each = 1.25
            let events = chords(rhodes, each: each, [[60, 64, 67, 71], [57, 60, 64, 67], [50, 57, 62, 65], [55, 59, 62, 65]])
            return Song(seconds: each * 4 + 0.4, events: events)

        case .groove:
            let kick = SynthVoice(wave: .sine, attack: 0.001, decay: 0.11, gain: 0.95)
            let hat = SynthVoice(wave: .noise, attack: 0.001, decay: 0.028, gain: 0.22)
            let bass = SynthVoice(wave: .triangle, decay: 0.18, sustain: 0.25, gain: 0.5)
            let stab = SynthVoice(wave: .saw, decay: 0.16, cutoffStart: 2600, cutoffEnd: 900, cutoffTime: 0.12, gain: 0.32)
            let step = 0.15
            var events: [SynthEvent] = []
            for s in [0, 4, 8, 12] { events.append(SynthEvent(start: Double(s) * step, duration: 0.1, freqs: [52], voice: kick)) }
            for s in [2, 6, 10, 14] { events.append(SynthEvent(start: Double(s) * step, duration: 0.03, freqs: [8000], voice: hat)) }
            events += melody(bass, beat: step * 2, [40, 40, 43, 45, 36, 36, 41, 43])
            events += chords(stab, each: step * 8, gate: 0.2, [[64, 67, 72], [65, 69, 72]])
            return Song(seconds: step * 16, events: events)

        case .crickets:
            var rng = Rand(state: 0xC417)
            let bed = SynthVoice(wave: .noise, attack: 0.4, sustain: 0.7, release: 0.5, cutoffStart: 700, cutoffEnd: 700, gain: 0.12)
            let chirp = SynthVoice(wave: .square, attack: 0.002, decay: 0.018, pulseWidth: 0.3, gain: 0.22)
            var events = [SynthEvent(start: 0, duration: 2.2, freqs: [300], voice: bed)]
            var at = 0.2
            while at < 2.4 {
                let pitch = rng.range(4200, 4800)
                for k in 0..<4 {
                    events.append(SynthEvent(start: at + Double(k) * 0.028, duration: 0.02, freqs: [pitch], voice: chirp))
                }
                at += rng.range(0.45, 0.8)
            }
            return Song(seconds: 2.6, events: events)

        case .droplets:
            // Clean water "plinks": high sine with a subtle upward bend, spaced out.
            var rng = Rand(state: 0xD409)
            var events: [SynthEvent] = []
            var at = 0.1
            while at < 3.2 {
                let drop = SynthVoice(wave: .sine, attack: 0.001, decay: 0.11, gain: rng.range(0.3, 0.5), bend: 1.1)
                events.append(SynthEvent(start: at, duration: 0.12, freqs: [rng.range(900, 1700)], voice: drop))
                at += rng.range(0.25, 0.6)
            }
            return Song(seconds: 3.4, events: events)

        case .windChimes:
            // Random metallic (FM) bells from a pentatonic set, overlapping into a shimmer.
            var rng = Rand(state: 0x5EED)
            let scale = [60, 62, 64, 67, 69, 72, 74, 76]
            var events: [SynthEvent] = []
            var at = 0.1
            while at < 3.0 {
                let midi = scale[Int(rng.range(0, Double(scale.count)))]
                let bell = SynthVoice(fmRatio: 1.41, fmIndex: 2.6, attack: 0.002, decay: 0.5, gain: rng.range(0.22, 0.42))
                events.append(SynthEvent(start: at, duration: 0.5, freqs: [hz(midi)], voice: bell))
                at += rng.range(0.18, 0.5)
            }
            return Song(seconds: 4.4, events: events)

        case .vibraphone:
            // Warm FM mallet with a slow tremolo shimmer playing a gentle phrase.
            let vibe = SynthVoice(fmRatio: 4, fmIndex: 0.55, attack: 0.003, decay: 0.6, gain: 0.5, tremoloHz: 5.5, tremoloDepth: 0.38)
            let beat = 0.32
            let events = melody(vibe, beat: beat, gate: 0.95, [72, 76, 79, 76, 72, 69, 67, nil])
            return Song(seconds: beat * 8, events: events)
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
