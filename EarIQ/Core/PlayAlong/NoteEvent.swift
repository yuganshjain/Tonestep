import Foundation

/// The only vocabulary the play-along engine understands. Every input source —
/// MIDI, on-screen keys, and later microphone detection — produces these.
struct NoteEvent: Equatable {
    let midiNote: UInt8
    let velocity: UInt8
    let isOn: Bool
    /// Seconds, in the same clock domain as the engine.
    let timestamp: TimeInterval
}
