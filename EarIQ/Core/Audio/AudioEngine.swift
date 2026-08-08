import AVFoundation
import Foundation

/// Central audio engine for playing musical notes using bundled .caf samples.
/// Falls back to AVAudioUnitSampler with General MIDI soundfont if samples are missing.
final class AudioEngine: ObservableObject {
    static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private var isRunning = false

    private init() {
        setupSession()
        setupEngine()
        observeInterruptions()
    }

    // MARK: - Setup

    private func setupSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func setupEngine() {
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        loadSoundfont()
        startEngine()
    }

    private func loadSoundfont() {
        // Load bundled soundfont if available, otherwise use default GM soundfont
        if let url = Bundle.main.url(forResource: "GeneralUser_GS", withExtension: "sf2") {
            try? sampler.loadSoundBankInstrument(at: url, program: 0, bankMSB: 0x79, bankLSB: 0)
        }
        // Program 0 = Acoustic Grand Piano (default MIDI instrument)
    }

    private func startEngine() {
        guard !isRunning else { return }
        do {
            try engine.start()
            isRunning = true
        } catch {
            print("AudioEngine start error: \(error)")
        }
    }

    // MARK: - Interruption Handling

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            isRunning = false
        case .ended:
            try? AVAudioSession.sharedInstance().setActive(true)
            startEngine()
        @unknown default: break
        }
    }

    // MARK: - Playback API

    /// Play a single MIDI note.
    func playNote(midiNote: UInt8, velocity: UInt8 = 80, duration: TimeInterval = 1.0) {
        sampler.startNote(midiNote, withVelocity: velocity, onChannel: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.sampler.stopNote(midiNote, onChannel: 0)
        }
    }

    /// Play two notes as an interval (ascending/descending/harmonic).
    func playInterval(
        rootMidi: UInt8,
        interval: Interval,
        direction: IntervalDirection,
        velocity: UInt8 = 80,
        noteDuration: TimeInterval = 0.8,
        gap: TimeInterval = 0.4
    ) {
        let secondMidi = UInt8(clamping: Int(rootMidi) + interval.rawValue)
        switch direction {
        case .ascending:
            playNote(midiNote: rootMidi, velocity: velocity, duration: noteDuration)
            DispatchQueue.main.asyncAfter(deadline: .now() + gap) {
                self.playNote(midiNote: secondMidi, velocity: velocity, duration: noteDuration)
            }
        case .descending:
            playNote(midiNote: secondMidi, velocity: velocity, duration: noteDuration)
            DispatchQueue.main.asyncAfter(deadline: .now() + gap) {
                self.playNote(midiNote: rootMidi, velocity: velocity, duration: noteDuration)
            }
        case .harmonic:
            playNote(midiNote: rootMidi, velocity: velocity, duration: noteDuration)
            playNote(midiNote: secondMidi, velocity: velocity, duration: noteDuration)
        }
    }

    /// Play a chord (all notes simultaneously).
    func playChord(rootMidi: UInt8, quality: ChordQuality, velocity: UInt8 = 75, duration: TimeInterval = 2.0) {
        for semitone in quality.semitones {
            let note = UInt8(clamping: Int(rootMidi) + semitone)
            playNote(midiNote: note, velocity: velocity, duration: duration)
        }
    }

    /// Play a scale ascending.
    func playScale(rootMidi: UInt8, type: ScaleType, tempo: TimeInterval = 0.25) {
        for (i, semitone) in type.semitones.enumerated() {
            let note = UInt8(clamping: Int(rootMidi) + semitone)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * tempo) {
                self.playNote(midiNote: note, velocity: 80, duration: tempo * 1.8)
            }
        }
    }

    /// Play a cadence (I-IV-V-I) to establish a key context for functional ear training.
    func playCadence(rootMidi: UInt8, tempo: TimeInterval = 0.5) {
        let chordRoots: [Int] = [0, 5, 7, 0]
        let qualities: [ChordQuality] = [.major, .major, .major, .major]
        for (i, (offset, quality)) in zip(chordRoots, qualities).enumerated() {
            let root = UInt8(clamping: Int(rootMidi) + offset)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * tempo) {
                self.playChord(rootMidi: root, quality: quality, duration: tempo * 1.8)
            }
        }
    }

    /// Play a melody (array of MIDI notes) at given tempo.
    func playMelody(midiNotes: [UInt8], tempo: TimeInterval = 0.4) {
        for (i, note) in midiNotes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * tempo) {
                self.playNote(midiNote: note, velocity: 80, duration: tempo * 1.6)
            }
        }
    }

    func stopAll() {
        for note: UInt8 in 0...127 {
            sampler.stopNote(note, onChannel: 0)
        }
    }
}
