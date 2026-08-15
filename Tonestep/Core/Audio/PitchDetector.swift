import AVFoundation
import Foundation

/// Real-time pitch detector using autocorrelation on mic input.
/// Used by rhythm clap-back and melodic sing-back exercises.
final class PitchDetector: ObservableObject {
    /// Why listening could not start. Surfaced so the UI can explain itself
    /// rather than silently doing nothing.
    enum FailureReason: Equatable {
        case permissionDenied
        case unavailable
    }

    @Published var detectedMidi: Int? = nil
    @Published var isListening = false
    @Published var failureReason: FailureReason? = nil

    private let engine = AVAudioEngine()
    private let bufferSize: AVAudioFrameCount = 4096
    private var didInstallTap = false

    func startListening() {
        guard !isListening else { return }
        requestMicPermission { [weak self] granted in
            guard let self else { return }
            guard granted else {
                DispatchQueue.main.async { self.failureReason = .permissionDenied }
                return
            }
            self.beginCapture()
        }
    }

    func stopListening() {
        guard didInstallTap else {
            isListening = false
            return
        }
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        didInstallTap = false
        isListening = false
        // Hand the session back to playback so drills are not stuck routing
        // through the earpiece after a singing exercise.
        restorePlaybackSession()
    }

    private func requestMicPermission(completion: @escaping (Bool) -> Void) {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            completion(true)
        case .undetermined:
            AVAudioApplication.requestRecordPermission { completion($0) }
        case .denied:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private func beginCapture() {
        // AudioEngine configures the shared session as .playback, which does not
        // permit recording. Under that category the input node reports a zero
        // format and installTap raises an ObjC exception, aborting the process.
        guard configureRecordingSession() else { return }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        // A zero-channel or zero-rate format still throws. Fail visibly instead.
        guard format.channelCount > 0, format.sampleRate > 0 else {
            restorePlaybackSession()
            DispatchQueue.main.async { self.failureReason = .unavailable }
            return
        }

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }
        didInstallTap = true

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            didInstallTap = false
            restorePlaybackSession()
            DispatchQueue.main.async { self.failureReason = .unavailable }
            return
        }
        DispatchQueue.main.async {
            self.failureReason = nil
            self.isListening = true
        }
    }

    private func configureRecordingSession() -> Bool {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
            return true
        } catch {
            DispatchQueue.main.async { self.failureReason = .unavailable }
            return false
        }
    }

    private func restorePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        guard let frequency = autocorrelation(data: channelData, count: frameCount, sampleRate: sampleRate),
              frequency > 20 else { return }
        let midi = frequencyToMidi(frequency)
        DispatchQueue.main.async { self.detectedMidi = midi }
    }

    private func autocorrelation(data: UnsafePointer<Float>, count: Int, sampleRate: Double) -> Double? {
        let minPeriod = Int(sampleRate / 1000)  // max 1000 Hz
        let maxPeriod = Int(sampleRate / 60)    // min 60 Hz

        var bestLag = minPeriod
        var bestCorrelation = Double.leastNormalMagnitude

        for lag in minPeriod...min(maxPeriod, count / 2) {
            var correlation: Double = 0
            for i in 0..<(count - lag) {
                correlation += Double(data[i]) * Double(data[i + lag])
            }
            if correlation > bestCorrelation {
                bestCorrelation = correlation
                bestLag = lag
            }
        }

        guard bestCorrelation > 0.01 else { return nil }
        return sampleRate / Double(bestLag)
    }

    private func frequencyToMidi(_ frequency: Double) -> Int {
        Int(round(69 + 12 * log2(frequency / 440.0)))
    }
}
