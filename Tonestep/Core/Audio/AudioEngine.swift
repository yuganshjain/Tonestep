import AVFoundation
import Foundation

/// Central audio engine for playing musical notes using bundled .caf samples.
/// Falls back to AVAudioUnitSampler with General MIDI soundfont if samples are missing.
final class AudioEngine: ObservableObject {
    static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private let sampler = AVAudioUnitSampler()
    private var isRunning = false

    /// True once a real soundfont has been loaded. Until then the sampler only
    /// produces a bare sine, so synthesised voices are used instead.
    private var hasSoundfont = false

    /// Voices are rendered ahead of playback; this pool avoids reallocating a
    /// player node per note.
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private let playerCount = 12
    private let renderFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    /// The instrument chosen during onboarding. Set by the app at launch.
    var instrument: Instrument = .piano

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

        for _ in 0..<playerCount {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: renderFormat)
            players.append(player)
        }

        loadSoundfont()
        startEngine()
        players.forEach { $0.play() }
    }

    /// Drop a General MIDI soundfont named GeneralUser_GS.sf2 into the bundle and
    /// playback switches to it automatically. Until then, ToneRenderer synthesises
    /// the voices, because an unloaded AVAudioUnitSampler is just a sine wave.
    private func loadSoundfont() {
        guard let url = Bundle.main.url(forResource: "GeneralUser_GS", withExtension: "sf2") else {
            hasSoundfont = false
            return
        }
        do {
            try sampler.loadSoundBankInstrument(at: url, program: instrument.generalMidiProgram,
                                                bankMSB: 0x79, bankLSB: 0)
            hasSoundfont = true
        } catch {
            hasSoundfont = false
        }
    }

    /// Re-point playback when the user changes instrument in Settings.
    func setInstrument(_ newInstrument: Instrument) {
        instrument = newInstrument
        if Bundle.main.url(forResource: "GeneralUser_GS", withExtension: "sf2") != nil {
            loadSoundfont()
        }
    }

    /// Synthesise and schedule one note on the next free player.
    private func playSynthesised(midiNote: UInt8, velocity: UInt8, duration: TimeInterval) {
        let samples = ToneRenderer.render(midiNote: midiNote, instrument: instrument,
                                          duration: duration, velocity: velocity,
                                          sampleRate: renderFormat.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: renderFormat,
                                            frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0]
        else { return }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }

        let player = players[nextPlayer % players.count]
        nextPlayer += 1
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
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
    /// Every other playback method funnels through here, so routing this one
    /// switches the whole app between the soundfont and the synthesised voices.
    func playNote(midiNote: UInt8, velocity: UInt8 = 80, duration: TimeInterval = 1.0) {
        guard hasSoundfont else {
            playSynthesised(midiNote: midiNote, velocity: velocity, duration: duration)
            return
        }
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

    /// Play a chord progression.
    func playChordProgression(_ progression: ChordProgression, rootMidi: UInt8, tempo: TimeInterval = 0.9) {
        for (i, (offset, quality)) in zip(progression.rootOffsets, progression.qualities).enumerated() {
            let root = UInt8(clamping: Int(rootMidi) + offset)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * tempo) {
                self.playChord(rootMidi: root, quality: quality, duration: tempo * 1.8)
            }
        }
    }

    /// Play a rhythm pattern with a click sound (uses note 76 = Hi Wood Block).
    func playRhythmPattern(_ pattern: RhythmPattern, completion: (() -> Void)? = nil) {
        var offset: Double = 0
        let baseTime = 60.0 / Double(pattern.bpm)
        for beat in pattern.beats {
            let duration = beat.duration * baseTime * 2
            if !beat.isRest {
                let t = offset
                DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                    // playNote owns note-off for both paths, so no manual stop here.
                    self.playNote(midiNote: 76, velocity: 100, duration: 0.12)
                }
            }
            offset += duration
        }
        if let completion {
            DispatchQueue.main.asyncAfter(deadline: .now() + offset + 0.2) { completion() }
        }
    }

    func stopAll() {
        // Synthesised voices are scheduled buffers, not held notes.
        players.forEach { $0.stop(); $0.play() }
        for note: UInt8 in 0...127 {
            sampler.stopNote(note, onChannel: 0)
        }
    }
}
