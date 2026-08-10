import Foundation

/// Per-instrument timbre: relative harmonic amplitudes plus an amplitude envelope.
///
/// This exists because AVAudioUnitSampler produces a bare sine unless a soundbank
/// is loaded, and no .sf2 is bundled — so the instrument the user picks during
/// onboarding had no audible effect at all. Synthesising here makes that promise
/// real without shipping (or licensing) a multi-megabyte soundfont.
struct InstrumentVoice {
    /// Amplitude of each harmonic, starting at the fundamental.
    let harmonics: [Float]
    /// Seconds to reach full amplitude.
    let attack: Float
    /// Seconds from peak down to the sustain level.
    let decay: Float
    /// Fraction of peak held while the note sounds. 0 = fully plucked/struck.
    let sustain: Float
    /// Seconds to fade out at note end.
    let release: Float
    /// Vibrato depth in cents. 0 for struck/plucked instruments.
    let vibratoCents: Float
    /// Vibrato rate in Hz.
    let vibratoHz: Float
    /// Slight sharpening of upper partials, as in real strings.
    let inharmonicity: Float

    static func voice(for instrument: Instrument) -> InstrumentVoice {
        switch instrument {
        case .piano:
            // Bright strike, quick decay, never truly sustains.
            return InstrumentVoice(harmonics: [1.0, 0.55, 0.32, 0.18, 0.11, 0.06],
                                   attack: 0.004, decay: 0.9, sustain: 0.18, release: 0.22,
                                   vibratoCents: 0, vibratoHz: 0, inharmonicity: 0.0004)
        case .guitar:
            // Plucked: fast attack, strong low harmonics, medium decay.
            return InstrumentVoice(harmonics: [1.0, 0.42, 0.28, 0.12, 0.07],
                                   attack: 0.003, decay: 0.7, sustain: 0.12, release: 0.25,
                                   vibratoCents: 0, vibratoHz: 0, inharmonicity: 0.0002)
        case .bass:
            // Fundamental-heavy, little upper content, long decay.
            return InstrumentVoice(harmonics: [1.0, 0.30, 0.10, 0.04],
                                   attack: 0.006, decay: 1.1, sustain: 0.25, release: 0.30,
                                   vibratoCents: 0, vibratoHz: 0, inharmonicity: 0.0001)
        case .violin:
            // Bowed: slow attack, full sustain, rich odd harmonics, vibrato.
            return InstrumentVoice(harmonics: [1.0, 0.70, 0.50, 0.36, 0.24, 0.16, 0.10],
                                   attack: 0.09, decay: 0.15, sustain: 0.85, release: 0.18,
                                   vibratoCents: 22, vibratoHz: 5.5, inharmonicity: 0)
        case .voice:
            // Sung: soft attack, sustained, gentle harmonics, slower vibrato.
            return InstrumentVoice(harmonics: [1.0, 0.45, 0.22, 0.10, 0.05],
                                   attack: 0.06, decay: 0.2, sustain: 0.80, release: 0.20,
                                   vibratoCents: 16, vibratoHz: 4.8, inharmonicity: 0)
        }
    }
}

/// Renders a single note to raw samples. Pure and deterministic, so the timbre
/// characteristics can be unit-tested rather than merely listened to.
enum ToneRenderer {

    static func frequency(forMidiNote note: UInt8) -> Float {
        440.0 * pow(2.0, (Float(note) - 69.0) / 12.0)
    }

    /// - Returns: mono samples in -1...1, `duration` seconds long.
    static func render(midiNote: UInt8,
                       instrument: Instrument,
                       duration: TimeInterval,
                       velocity: UInt8 = 80,
                       sampleRate: Double = 44_100) -> [Float] {
        let voice = InstrumentVoice.voice(for: instrument)
        let frameCount = max(1, Int(duration * sampleRate))
        let baseFrequency = frequency(forMidiNote: midiNote)
        let amplitude = min(1.0, Float(velocity) / 127.0)

        // Normalise so summed harmonics cannot clip.
        let harmonicSum = voice.harmonics.reduce(0, +)
        let normalise = harmonicSum > 0 ? 1.0 / harmonicSum : 1.0

        var samples = [Float](repeating: 0, count: frameCount)
        let sr = Float(sampleRate)

        for frame in 0..<frameCount {
            let t = Float(frame) / sr

            // Vibrato as a multiplicative pitch offset in cents.
            var pitchScale: Float = 1
            if voice.vibratoCents > 0 {
                let cents = voice.vibratoCents * sin(2 * .pi * voice.vibratoHz * t)
                pitchScale = pow(2, cents / 1200)
            }

            var value: Float = 0
            for (index, harmonicAmplitude) in voice.harmonics.enumerated() {
                let partial = Float(index + 1)
                // Real strings sharpen with partial number; this keeps piano from
                // sounding like a pure organ.
                let stretch = 1 + voice.inharmonicity * partial * partial
                let f = baseFrequency * partial * stretch * pitchScale
                guard f < sr / 2 else { continue }   // above Nyquist: skip, don't alias
                value += harmonicAmplitude * sin(2 * .pi * f * t)
            }

            samples[frame] = value * normalise * amplitude * envelope(at: t, voice: voice,
                                                                     duration: Float(duration))
        }
        return samples
    }

    /// Standard ADSR, evaluated at time `t`.
    static func envelope(at t: Float, voice: InstrumentVoice, duration: Float) -> Float {
        guard t >= 0, t <= duration else { return 0 }

        let releaseStart = max(0, duration - voice.release)
        if t >= releaseStart, voice.release > 0 {
            let levelAtRelease = levelBeforeRelease(at: releaseStart, voice: voice)
            let progress = (t - releaseStart) / voice.release
            return levelAtRelease * max(0, 1 - progress)
        }
        return levelBeforeRelease(at: t, voice: voice)
    }

    private static func levelBeforeRelease(at t: Float, voice: InstrumentVoice) -> Float {
        if t < voice.attack, voice.attack > 0 {
            return t / voice.attack
        }
        let sinceAttack = t - voice.attack
        if sinceAttack < voice.decay, voice.decay > 0 {
            let progress = sinceAttack / voice.decay
            return 1 - (1 - voice.sustain) * progress
        }
        return voice.sustain
    }
}
