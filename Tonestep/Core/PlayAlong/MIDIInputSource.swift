import Foundation
import CoreMIDI
import QuartzCore
import Combine

/// Thin CoreMIDI adapter. Deliberately contains no judging logic: MIDI hardware
/// is unavailable in the Simulator, so anything in here cannot be unit-tested.
final class MIDIInputSource: NSObject, NoteInputSource, ObservableObject {

    var onEvent: ((NoteEvent) -> Void)?
    @Published private(set) var connectedDeviceName: String?

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        isRunning = true

        MIDIClientCreateWithBlock("Tonestep" as CFString, &client) { [weak self] _ in
            // Devices come and go; re-scan so a mid-lesson reconnect keeps working.
            self?.connectAllSources()
        }

        MIDIInputPortCreateWithProtocol(
            client, "Tonestep Input" as CFString, ._1_0, &inputPort
        ) { [weak self] eventList, _ in
            self?.handle(eventList: eventList)
        }

        connectAllSources()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        if inputPort != 0 { MIDIPortDispose(inputPort); inputPort = 0 }
        if client != 0 { MIDIClientDispose(client); client = 0 }
        connectedDeviceName = nil
    }

    private func connectAllSources() {
        let count = MIDIGetNumberOfSources()
        var firstName: String?
        for index in 0..<count {
            let source = MIDIGetSource(index)
            MIDIPortConnectSource(inputPort, source, nil)
            if firstName == nil {
                var cfName: Unmanaged<CFString>?
                if MIDIObjectGetStringProperty(source, kMIDIPropertyDisplayName, &cfName) == noErr {
                    firstName = cfName?.takeRetainedValue() as String?
                }
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.connectedDeviceName = firstName
        }
    }

    private func handle(eventList: UnsafePointer<MIDIEventList>) {
        // Hardware timestamps are mach absolute time. Convert once, here at the
        // boundary, so the engine only ever sees its own clock domain.
        let now = CACurrentMediaTime()

        var packet = eventList.pointee.packet
        for _ in 0..<eventList.pointee.numPackets {
            let wordCount = Int(packet.wordCount)
            withUnsafeBytes(of: packet.words) { raw in
                let words = raw.bindMemory(to: UInt32.self)
                for index in 0..<min(wordCount, words.count) {
                    process(word: words[index], at: now)
                }
            }
            packet = MIDIEventPacketNext(&packet).pointee
        }
    }

    /// MIDI 1.0 channel-voice message packed into a UMP word:
    /// status in bits 20-23, note in 8-15, velocity in 0-7.
    private func process(word: UInt32, at now: TimeInterval) {
        let status = UInt8((word >> 20) & 0xF)
        let note = UInt8((word >> 8) & 0x7F)
        let velocity = UInt8(word & 0x7F)

        // Note-on with velocity 0 is conventionally a note-off.
        if status == 0x9 && velocity > 0 {
            emit(NoteEvent(midiNote: note, velocity: velocity, isOn: true, timestamp: now))
        } else if status == 0x8 || (status == 0x9 && velocity == 0) {
            emit(NoteEvent(midiNote: note, velocity: 0, isOn: false, timestamp: now))
        }
    }

    private func emit(_ event: NoteEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.onEvent?(event)
        }
    }
}
