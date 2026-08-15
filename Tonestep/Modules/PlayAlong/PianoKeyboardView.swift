import SwiftUI
import QuartzCore

/// Tappable-keyboard input. Not a fallback bolted on late — without it the
/// feature cannot be run or demoed in the Simulator at all.
final class OnScreenInputSource: NoteInputSource, ObservableObject {
    var onEvent: ((NoteEvent) -> Void)?
    private var isRunning = false

    func start() { isRunning = true }
    func stop() { isRunning = false }

    func press(_ midiNote: UInt8) {
        guard isRunning else { return }

        // Sound the note. This was missing: the keyboard only ever forwarded
        // events to the judging engine, so pressing a key was completely
        // silent — you could play a whole piece and hear nothing. A MIDI
        // keyboard makes its own sound; an on-screen one has to be given one.
        AudioEngine.shared.playNote(midiNote: midiNote, velocity: 100, duration: 0.6)

        let now = CACurrentMediaTime()
        onEvent?(NoteEvent(midiNote: midiNote, velocity: 100, isOn: true, timestamp: now))
        onEvent?(NoteEvent(midiNote: midiNote, velocity: 0, isOn: false, timestamp: now + 0.2))
    }
}

struct PianoKeyboardView: View {
    let lowestNote: UInt8
    let octaves: Int
    /// Notes the lesson currently expects, highlighted as a hint.
    let highlighted: Set<UInt8>
    let source: OnScreenInputSource

    private let whiteOffsets = [0, 2, 4, 5, 7, 9, 11]
    private let blackOffsets = [1, 3, 6, 8, 10]

    private var whiteNotes: [UInt8] {
        (0..<octaves).flatMap { octave in
            whiteOffsets.map { UInt8(Int(lowestNote) + octave * 12 + $0) }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let whiteWidth = geo.size.width / CGFloat(whiteNotes.count)

            ZStack(alignment: .topLeading) {
                // Positioned explicitly rather than in an HStack: inter-key
                // spacing accumulates drift against the offset-positioned black
                // keys, which left a white key visibly missing between octaves.
                ForEach(Array(whiteNotes.enumerated()), id: \.element) { index, note in
                    Rectangle()
                        .fill(highlighted.contains(note) ? Color.appPurple.opacity(0.35) : Color.white)
                        .frame(width: whiteWidth, height: geo.size.height)
                        .overlay(Rectangle().stroke(Color.black.opacity(0.18), lineWidth: 0.5))
                        .offset(x: CGFloat(index) * whiteWidth)
                        .contentShape(Rectangle())
                        .onTapGesture { source.press(note) }
                }

                ForEach(blackKeys(whiteWidth: whiteWidth), id: \.note) { key in
                    Rectangle()
                        .fill(highlighted.contains(key.note) ? Color.appPurple : Color.black)
                        .frame(width: whiteWidth * 0.6, height: geo.size.height * 0.62)
                        .offset(x: key.x)
                        .contentShape(Rectangle())
                        .onTapGesture { source.press(key.note) }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private struct BlackKey { let note: UInt8; let x: CGFloat }

    private func blackKeys(whiteWidth: CGFloat) -> [BlackKey] {
        var keys: [BlackKey] = []
        for octave in 0..<octaves {
            for offset in blackOffsets {
                let note = UInt8(Int(lowestNote) + octave * 12 + offset)
                // Count white keys below this pitch to place the key on the boundary.
                let whitesBelow = whiteOffsets.filter { $0 < offset }.count
                let index = CGFloat(octave * 7 + whitesBelow)
                keys.append(BlackKey(note: note, x: index * whiteWidth - whiteWidth * 0.3))
            }
        }
        return keys
    }
}
