import Foundation

struct LessonNote: Codable, Equatable {
    let midiNote: UInt8
    let startBeat: Double
    let durationBeats: Double
}

/// Positions are in beats rather than seconds so tempo can be changed without
/// rewriting content — required for practice-slower.
struct LessonPiece: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let bpm: Double
    let beatsPerBar: Int
    let notes: [LessonNote]
    /// 1 (a few adjacent notes) to 5 (wide leaps, accidentals, faster tempo).
    /// Defaulted so older content without the field still decodes.
    var difficulty: Int = 1
    /// nil for traditional/folk material with no single attributable composer.
    var composer: String?

    var difficultyLabel: String {
        switch difficulty {
        case 1: return "Beginner"
        case 2: return "Easy"
        case 3: return "Intermediate"
        case 4: return "Advanced"
        default: return "Challenging"
        }
    }

    /// Lowest and highest note, so the UI can show the span a piece demands.
    var range: ClosedRange<UInt8>? {
        guard let low = notes.map(\.midiNote).min(),
              let high = notes.map(\.midiNote).max() else { return nil }
        return low...high
    }

    /// e.g. "C4–E5". Tells a player at a glance whether it fits their hand.
    var rangeDescription: String? {
        guard let range else { return nil }
        return "\(LessonPiece.noteName(range.lowerBound))–\(LessonPiece.noteName(range.upperBound))"
    }

    /// Scientific pitch notation, where MIDI 60 is C4.
    static func noteName(_ midi: UInt8) -> String {
        let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
        let octave = Int(midi) / 12 - 1
        return "\(names[Int(midi) % 12])\(octave)"
    }

    func secondsForBeat(_ beat: Double) -> TimeInterval {
        beat * 60.0 / bpm
    }

    var duration: TimeInterval {
        guard let last = notes.max(by: { $0.startBeat + $0.durationBeats < $1.startBeat + $1.durationBeats })
        else { return 0 }
        return secondsForBeat(last.startBeat + last.durationBeats)
    }
}

enum LessonLibrary {
    /// All pieces bundled under Resources/Lessons.
    static let all: [LessonPiece] = {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Lessons")
        else { return [] }
        let decoder = JSONDecoder()
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(LessonPiece.self, from: data)
        }
        .sorted { $0.id < $1.id }
    }()

    static func piece(id: String) -> LessonPiece? {
        all.first { $0.id == id }
    }

    /// Pieces grouped into difficulty tiers, easiest first, with empty tiers
    /// omitted so the UI never renders a heading with nothing under it.
    static var byDifficulty: [(tier: Int, label: String, pieces: [LessonPiece])] {
        Dictionary(grouping: all, by: \.difficulty)
            .sorted { $0.key < $1.key }
            .map { (tier: $0.key,
                    label: $0.value[0].difficultyLabel,
                    pieces: $0.value.sorted { $0.notes.count < $1.notes.count }) }
    }
}
