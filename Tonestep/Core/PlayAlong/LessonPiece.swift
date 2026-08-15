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
}
