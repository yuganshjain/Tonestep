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
