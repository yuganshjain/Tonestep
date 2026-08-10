import XCTest
@testable import Tonestep

final class ToneRendererTests: XCTestCase {

    func test_a440_is_midi_69() {
        XCTAssertEqual(ToneRenderer.frequency(forMidiNote: 69), 440.0, accuracy: 0.01)
    }

    func test_octave_doubles_frequency() {
        XCTAssertEqual(ToneRenderer.frequency(forMidiNote: 81),
                       ToneRenderer.frequency(forMidiNote: 69) * 2, accuracy: 0.01)
    }

    func test_middle_c_frequency() {
        XCTAssertEqual(ToneRenderer.frequency(forMidiNote: 60), 261.63, accuracy: 0.05)
    }

    func test_render_produces_the_requested_length() {
        let samples = ToneRenderer.render(midiNote: 60, instrument: .piano,
                                          duration: 0.5, sampleRate: 8_000)
        XCTAssertEqual(samples.count, 4_000)
    }

    func test_samples_never_clip() {
        for instrument in Instrument.allCases {
            let samples = ToneRenderer.render(midiNote: 60, instrument: instrument,
                                              duration: 0.4, sampleRate: 8_000)
            let peak = samples.map(abs).max() ?? 0
            XCTAssertLessThanOrEqual(peak, 1.0, "\(instrument.rawValue) clips at \(peak)")
        }
    }

    func test_samples_are_finite() {
        for instrument in Instrument.allCases {
            let samples = ToneRenderer.render(midiNote: 72, instrument: instrument,
                                              duration: 0.3, sampleRate: 8_000)
            XCTAssertFalse(samples.contains { !$0.isFinite }, "\(instrument.rawValue) produced NaN/inf")
        }
    }

    func test_render_is_deterministic() {
        let a = ToneRenderer.render(midiNote: 64, instrument: .violin, duration: 0.2, sampleRate: 8_000)
        let b = ToneRenderer.render(midiNote: 64, instrument: .violin, duration: 0.2, sampleRate: 8_000)
        XCTAssertEqual(a, b)
    }

    func test_note_actually_sounds() {
        let samples = ToneRenderer.render(midiNote: 60, instrument: .piano,
                                          duration: 0.3, sampleRate: 8_000)
        let peak = samples.map(abs).max() ?? 0
        XCTAssertGreaterThan(peak, 0.01, "rendered note is silent")
    }

    func test_instruments_produce_different_waveforms() {
        // The whole point of this work: the onboarding instrument choice must be audible.
        let piano = ToneRenderer.render(midiNote: 60, instrument: .piano, duration: 0.3, sampleRate: 8_000)
        let violin = ToneRenderer.render(midiNote: 60, instrument: .violin, duration: 0.3, sampleRate: 8_000)
        XCTAssertNotEqual(piano, violin)
    }

    func test_velocity_scales_amplitude() {
        let soft = ToneRenderer.render(midiNote: 60, instrument: .piano, duration: 0.3,
                                       velocity: 40, sampleRate: 8_000).map(abs).max() ?? 0
        let loud = ToneRenderer.render(midiNote: 60, instrument: .piano, duration: 0.3,
                                       velocity: 120, sampleRate: 8_000).map(abs).max() ?? 0
        XCTAssertGreaterThan(loud, soft)
    }

    func test_envelope_starts_and_ends_silent() {
        let voice = InstrumentVoice.voice(for: .piano)
        XCTAssertEqual(ToneRenderer.envelope(at: 0, voice: voice, duration: 1.0), 0, accuracy: 0.001)
        XCTAssertEqual(ToneRenderer.envelope(at: 1.0, voice: voice, duration: 1.0), 0, accuracy: 0.001)
    }

    func test_envelope_peaks_at_end_of_attack() {
        let voice = InstrumentVoice.voice(for: .violin)
        XCTAssertEqual(ToneRenderer.envelope(at: voice.attack, voice: voice, duration: 2.0),
                       1.0, accuracy: 0.01)
    }

    func test_envelope_outside_the_note_is_silent() {
        let voice = InstrumentVoice.voice(for: .piano)
        XCTAssertEqual(ToneRenderer.envelope(at: -0.1, voice: voice, duration: 1.0), 0, accuracy: 0.001)
        XCTAssertEqual(ToneRenderer.envelope(at: 1.5, voice: voice, duration: 1.0), 0, accuracy: 0.001)
    }

    /// Bowed instruments hold; struck instruments die away. If this inverts,
    /// the timbres have lost their defining characteristic.
    func test_bowed_sustains_more_than_struck() {
        XCTAssertGreaterThan(InstrumentVoice.voice(for: .violin).sustain,
                             InstrumentVoice.voice(for: .piano).sustain)
    }

    func test_bowed_attack_is_slower_than_struck() {
        XCTAssertGreaterThan(InstrumentVoice.voice(for: .violin).attack,
                             InstrumentVoice.voice(for: .piano).attack)
    }

    func test_bass_has_less_upper_harmonic_content_than_violin() {
        let bass = InstrumentVoice.voice(for: .bass).harmonics
        let violin = InstrumentVoice.voice(for: .violin).harmonics
        XCTAssertLessThan(bass.count, violin.count)
    }

    func test_high_notes_do_not_alias() {
        // Partials above Nyquist must be skipped, not folded back as noise.
        let samples = ToneRenderer.render(midiNote: 108, instrument: .violin,
                                          duration: 0.2, sampleRate: 8_000)
        XCTAssertFalse(samples.contains { !$0.isFinite })
        XCTAssertLessThanOrEqual(samples.map(abs).max() ?? 0, 1.0)
    }
}
