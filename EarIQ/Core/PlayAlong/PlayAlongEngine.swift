import Foundation

enum Judgement: String, Equatable {
    case perfect, good, late, missed
}

struct PlayAlongResult: Equatable {
    let accuracy: Double
    let stars: Int
    let perfect: Int
    let good: Int
    let late: Int
    let missed: Int
    let wrongNotes: Int
}

/// Judges input against a piece. Pure: no audio, no UI, no clock of its own —
/// time is supplied by the caller, which is what makes every window testable.
final class PlayAlongEngine {

    // Windows, in seconds, relative to a note's scheduled time.
    static let perfectWindow: TimeInterval = 0.050
    static let goodWindow: TimeInterval = 0.120
    static let lateWindow: TimeInterval = 0.250
    /// A note may be claimed this early. Matches the good window.
    static let earlyWindow: TimeInterval = 0.120

    /// Identical to PassCriteria.standard so a star means the same thing
    /// in Play-Along as it does in the curriculum.
    static let starThresholds: [Double] = [0.8, 0.9, 1.0]

    let piece: LessonPiece
    private let scheduled: [TimeInterval]
    private var lastUpdate: TimeInterval = -.infinity

    private(set) var judgements: [Judgement?]
    private(set) var wrongNoteCount = 0

    init(piece: LessonPiece, startTime: TimeInterval) {
        self.piece = piece
        self.scheduled = piece.notes.map { startTime + piece.secondsForBeat($0.startBeat) }
        self.judgements = Array(repeating: nil, count: piece.notes.count)
    }

    /// True once every note's window has closed.
    var isFinished: Bool {
        guard let last = scheduled.max() else { return true }
        return lastUpdate >= last + Self.lateWindow
    }

    func handle(event: NoteEvent) {
        // Onset-only. Releases are not judged in this slice.
        guard event.isOn else { return }

        if let index = matchIndex(for: event) {
            judgements[index] = judgement(delta: event.timestamp - scheduled[index])
            return
        }

        // An extra note is only a mistake once the piece is actually under way.
        // Noodling before the first window opens is ignored.
        if let firstWindowOpens = scheduled.min().map({ $0 - Self.earlyWindow }),
           event.timestamp >= firstWindowOpens {
            wrongNoteCount += 1
        }
    }

    /// Closes windows that have elapsed, marking unplayed notes as missed.
    func update(now: TimeInterval) {
        lastUpdate = max(lastUpdate, now)
        for index in piece.notes.indices where judgements[index] == nil {
            if now > scheduled[index] + Self.lateWindow {
                judgements[index] = .missed
            }
        }
    }

    func result() -> PlayAlongResult {
        let resolved = judgements.compactMap { $0 }
        let possible = piece.notes.count * 100
        guard possible > 0 else {
            return PlayAlongResult(accuracy: 0, stars: 0, perfect: 0, good: 0,
                                   late: 0, missed: 0, wrongNotes: wrongNoteCount)
        }

        let earned = resolved.reduce(0) { $0 + Self.points(for: $1) }
        let penalty = wrongNoteCount * 20
        let accuracy = Double(max(0, earned - penalty)) / Double(possible)
        let stars = Self.starThresholds.filter { accuracy >= $0 }.count

        return PlayAlongResult(
            accuracy: accuracy,
            stars: stars,
            perfect: resolved.filter { $0 == .perfect }.count,
            good:    resolved.filter { $0 == .good }.count,
            late:    resolved.filter { $0 == .late }.count,
            missed:  resolved.filter { $0 == .missed }.count,
            wrongNotes: wrongNoteCount
        )
    }

    // MARK: - Private

    private static func points(for judgement: Judgement) -> Int {
        switch judgement {
        case .perfect: return 100
        case .good:    return 70
        case .late:    return 40
        case .missed:  return 0
        }
    }

    /// The unjudged note of matching pitch whose window contains the event and
    /// whose scheduled time is nearest.
    private func matchIndex(for event: NoteEvent) -> Int? {
        piece.notes.indices
            .filter { index in
                judgements[index] == nil
                    && piece.notes[index].midiNote == event.midiNote
                    && event.timestamp >= scheduled[index] - Self.earlyWindow
                    && event.timestamp <= scheduled[index] + Self.lateWindow
            }
            .min { abs(event.timestamp - scheduled[$0]) < abs(event.timestamp - scheduled[$1]) }
    }

    private func judgement(delta: TimeInterval) -> Judgement {
        let magnitude = abs(delta)
        if magnitude <= Self.perfectWindow { return .perfect }
        if magnitude <= Self.goodWindow { return .good }
        return .late
    }
}
