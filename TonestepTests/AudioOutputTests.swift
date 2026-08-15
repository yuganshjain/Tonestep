import XCTest
import AVFoundation
@testable import Tonestep

/// Proves the playback chain actually produces audible samples.
///
/// Every other audio test checks numbers in isolation: ToneRenderer emits
/// non-zero floats, envelopes have the right shape. None of them prove that
/// those samples survive AVAudioEngine and reach the output. AVAudioEngine's
/// offline manual-rendering mode lets that be measured rather than assumed —
/// no speakers, no device, no ears required.
final class AudioOutputTests: XCTestCase {

    /// Root-mean-square of a rendered buffer. Silence is 0.
    private func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var sum: Float = 0
        for channel in 0..<Int(buffer.format.channelCount) {
            for frame in 0..<frames {
                let sample = data[channel][frame]
                sum += sample * sample
            }
        }
        return (sum / Float(frames * Int(buffer.format.channelCount))).squareRoot()
    }

    /// Renders a note through the same node graph AudioEngine uses:
    /// AVAudioPlayerNode -> mainMixerNode, buffer scheduled after start.
    private func renderNote(sampleRate: Double, instrument: Instrument = .piano) throws -> Float {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        let outputFormat = try XCTUnwrap(
            AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
                          channels: 2, interleaved: false)
        )
        try engine.enableManualRenderingMode(.offline, format: outputFormat,
                                             maximumFrameCount: 4096)
        try engine.start()
        player.play()

        let samples = ToneRenderer.render(midiNote: 60, instrument: instrument,
                                          duration: 0.5, sampleRate: sampleRate)
        let source = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
        )
        source.frameLength = AVAudioFrameCount(samples.count)
        let channel = try XCTUnwrap(source.floatChannelData)
        samples.withUnsafeBufferPointer {
            channel[0].update(from: $0.baseAddress!, count: samples.count)
        }
        player.scheduleBuffer(source, at: nil, options: [], completionHandler: nil)

        let out = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096)
        )
        var peak: Float = 0
        // Render ~0.5s worth in blocks and keep the loudest block.
        let blocks = Int((sampleRate * 0.5) / 4096) + 2
        for _ in 0..<blocks {
            let status = try engine.renderOffline(4096, to: out)
            if status == .success { peak = max(peak, rms(out)) }
        }
        engine.stop()
        return peak
    }

    /// The Simulator's rate. If this is silent, the chain is broken everywhere.
    func test_playback_chain_produces_audio_at_44100() throws {
        let level = try renderNote(sampleRate: 44_100)
        XCTAssertGreaterThan(level, 0.001, "playback chain produced silence at 44.1kHz")
    }

    /// Real iPhones run at 48kHz. This is the case that was silent on device.
    func test_playback_chain_produces_audio_at_48000() throws {
        let level = try renderNote(sampleRate: 48_000)
        XCTAssertGreaterThan(level, 0.001, "playback chain produced silence at 48kHz")
    }

    func test_every_instrument_is_audible() throws {
        for instrument in Instrument.allCases {
            let level = try renderNote(sampleRate: 48_000, instrument: instrument)
            XCTAssertGreaterThan(level, 0.001, "\(instrument.rawValue) rendered silent")
        }
    }

    /// The failure behind "sound works, then stops forever": AVAudioEngine drops
    /// every connection on a configuration change. A disconnected player still
    /// reports isPlaying == true and silently produces nothing, so reconnecting
    /// has to restore audio — and this proves it does.
    func test_audio_returns_after_reconnecting_the_graph() throws {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let outputFormat = try XCTUnwrap(
            AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
                          channels: 2, interleaved: false)
        )
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try engine.enableManualRenderingMode(.offline, format: outputFormat, maximumFrameCount: 4096)
        try engine.start()
        player.play()

        // Simulate the teardown a configuration change performs.
        player.stop()
        engine.stop()
        engine.disconnectNodeOutput(player)

        // Recovery, mirroring AudioEngine.rebuild().
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try engine.start()
        player.play()

        let samples = ToneRenderer.render(midiNote: 60, instrument: .piano,
                                          duration: 0.3, sampleRate: 48_000)
        let source = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
        )
        source.frameLength = AVAudioFrameCount(samples.count)
        source.floatChannelData!.pointee.update(from: samples, count: samples.count)
        player.scheduleBuffer(source, at: nil, options: [.interrupts], completionHandler: nil)

        let out = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096)
        )
        var peak: Float = 0
        for _ in 0..<6 {
            if try engine.renderOffline(4096, to: out) == .success {
                peak = max(peak, rms(out))
            }
        }
        engine.stop()
        XCTAssertGreaterThan(peak, 0.001, "audio did not come back after reconnecting")
    }

    /// A scheduled buffer on a player that was never started must not be
    /// mistaken for working audio.
    func test_unstarted_player_is_silent() throws {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)

        let outputFormat = try XCTUnwrap(
            AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
                          channels: 2, interleaved: false)
        )
        try engine.enableManualRenderingMode(.offline, format: outputFormat, maximumFrameCount: 4096)
        try engine.start()
        // deliberately no player.play()

        let samples = ToneRenderer.render(midiNote: 60, instrument: .piano,
                                          duration: 0.2, sampleRate: 48_000)
        let source = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))
        )
        source.frameLength = AVAudioFrameCount(samples.count)
        source.floatChannelData!.pointee.update(from: samples, count: samples.count)
        player.scheduleBuffer(source, at: nil, options: [], completionHandler: nil)

        let out = try XCTUnwrap(
            AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 4096)
        )
        _ = try engine.renderOffline(4096, to: out)
        engine.stop()
        XCTAssertLessThan(rms(out), 0.0001, "a stopped player should emit nothing")
    }
}
