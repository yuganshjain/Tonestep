import AVFoundation
import Foundation

/// Real-time pitch detector using autocorrelation on mic input.
/// Used by rhythm clap-back and melodic sing-back exercises.
final class PitchDetector: ObservableObject {
    @Published var detectedMidi: Int? = nil
    @Published var isListening = false

    private let engine = AVAudioEngine()
    private let bufferSize: AVAudioFrameCount = 4096

    func startListening() {
        guard !isListening else { return }
        requestMicPermission { [weak self] granted in
            guard granted, let self else { return }
            self.beginCapture()
        }
    }

    func stopListening() {
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        isListening = false
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
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }
        try? engine.start()
        DispatchQueue.main.async { self.isListening = true }
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
