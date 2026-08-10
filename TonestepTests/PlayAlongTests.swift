import XCTest
@testable import Tonestep

final class PlayAlongJudgingTests: XCTestCase {

    /// Two notes at 60bpm: C at beat 0 (t=0s), D at beat 1 (t=1s).
    private func twoNotePiece() -> LessonPiece {
        LessonPiece(id: "t", title: "T", bpm: 60, beatsPerBar: 4, notes: [
            LessonNote(midiNote: 60, startBeat: 0, durationBeats: 1),
            LessonNote(midiNote: 62, startBeat: 1, durationBeats: 1)
        ])
    }

    private func on(_ note: UInt8, at t: TimeInterval) -> NoteEvent {
        NoteEvent(midiNote: note, velocity: 100, isOn: true, timestamp: t)
    }

    func test_exactly_on_time_is_perfect() {
        let e = PlayAlongEngine(piece: twoNotePiece(), startTime: 0)
        e.handle(event: on(60, at: 0))
        XCTAssertEqual(e.judgements[0], .perfect)
    }

    func test_at_perfect_boundary_is_perfect() {
        let e = PlayAlongEngine(piece: twoNotePiece(), startTime: 0)
        e.handle(event: on(60, at: 0.050))
        XCTAssertEqual(e.judgements[0], .perfect)
    }

    func test_just_past_perfect_boundary_is_good() {
        let e = PlayAlongEngine(piece: twoNotePiece(), startTime: 0)
        e.handle(event: on(60, at: 0.051))
        XCTAssertEqual(e.judgements[0], .good)
    }

    func test_early_within_perfect_window_is_perfect() {
        let e = PlayAlongEngine(piece: twoNotePiece(), startTime: 0)
        e.handle(event: on(60, at: -0.040))
        XCTAssertEqual(e.judgements[0], .perfect)
    }

    func test_at_good_boundary_is_good() {
        let e = PlayAlongEngine(piece: twoNotePiece(), startTime: 0)
        e.handle(event: on(60, at: 0.120))
        XCTAssertEqual(e.judgements[0], .good)
    }

    func test_just_past_good_boundary_is_late() {
        let e = PlayAlongEngine(piece: twoNotePiece(), startTime: 0)
        e.handle(event: on(60, at: 0.121))
        XCTAssertEqual(e.judgements[0], .late)
    }

    func test_at_late_boundary_is_still_late() {
        let e = PlayAlongEngine(piece: twoNotePiece(), startTime: 0)
        e.handle(event: on(60, at: 0.250))
        XCTAssertEqual(e.judgements[0], .late)
    }

    func test_past_late_boundary_does_not_register() {
        let e = PlayAlongEngine(piece: twoNotePiece(), startTime: 0)
        e.handle(event: on(60, at: 0.251))
        XCTAssertNil(e.judgements[0])
        XCTAssertEqual(e.wrongNoteCount, 1)
    }

    func test_too_early_does_not_register_as_a_hit() {
        let e = PlayAlongEngine(piece: twoNotePiece(), startTime: 0)
        e.handle(event: on(60, at: -0.500))
        XCTAssertNil(e.judgements[0])
    }

    func test_events_before_the_piece_starts_are_not_penalised() {
        let e = PlayAlongEngine(piece: twoNotePiece(), startTime: 0)
        e.handle(event: on(60, at: -0.500))
        XCTAssertEqual(e.wrongNoteCount, 0, "noodling before the count-in must not be punished")
    }

    func test_wrong_pitch_is_a_wrong_note() {
        let e = PlayAlongEngine(piece: twoNotePiece(), startTime: 0)
        e.handle(event: on(61, at: 0))
        XCTAssertNil(e.judgements[0])
        XCTAssertEqual(e.wrongNoteCount, 1)
    }

    func test_missed_note_marked_once_time_passes() {
        let e = PlayAlongEngine(piece: twoNotePiece(), startTime: 0)
        e.update(now: 0.300)
        XCTAssertEqual(e.judgements[0], .missed)
    }

    func test_note_not_marked_missed_before_its_window_closes() {
        let e = PlayAlongEngine(piece: twoNotePiece(), startTime: 0)
        e.update(now: 0.200)
        XCTAssertNil(e.judgements[0])
    }

    func test_note_off_events_are_ignored() {
        let e = PlayAlongEngine(piece: twoNotePiece(), startTime: 0)
        e.handle(event: NoteEvent(midiNote: 60, velocity: 0, isOn: false, timestamp: 0))
        XCTAssertNil(e.judgements[0])
        XCTAssertEqual(e.wrongNoteCount, 0)
    }

    func test_a_note_is_only_judged_once() {
        let e = PlayAlongEngine(piece: twoNotePiece(), startTime: 0)
        e.handle(event: on(60, at: 0))
        e.handle(event: on(60, at: 0.010))
        XCTAssertEqual(e.judgements[0], .perfect)
        XCTAssertEqual(e.wrongNoteCount, 1, "the second strike matches nothing open")
    }

    func test_startTime_offsets_the_schedule() {
        let e = PlayAlongEngine(piece: twoNotePiece(), startTime: 10)
        e.handle(event: on(60, at: 10))
        XCTAssertEqual(e.judgements[0], .perfect)
    }

    func test_chord_notes_are_judged_independently() {
        let piece = LessonPiece(id: "c", title: "C", bpm: 60, beatsPerBar: 4, notes: [
            LessonNote(midiNote: 60, startBeat: 0, durationBeats: 1),
            LessonNote(midiNote: 64, startBeat: 0, durationBeats: 1),
            LessonNote(midiNote: 67, startBeat: 0, durationBeats: 1)
        ])
        let e = PlayAlongEngine(piece: piece, startTime: 0)
        e.handle(event: on(60, at: 0.010))
        e.handle(event: on(64, at: 0.020))
        e.handle(event: on(67, at: 0.200))
        XCTAssertEqual(e.judgements[0], .perfect)
        XCTAssertEqual(e.judgements[1], .perfect)
        XCTAssertEqual(e.judgements[2], .late)
        XCTAssertEqual(e.wrongNoteCount, 0)
    }

    func test_repeated_pitch_matches_the_nearest_scheduled_note() {
        let piece = LessonPiece(id: "r", title: "R", bpm: 60, beatsPerBar: 4, notes: [
            LessonNote(midiNote: 60, startBeat: 0, durationBeats: 1),
            LessonNote(midiNote: 60, startBeat: 1, durationBeats: 1)
        ])
        let e = PlayAlongEngine(piece: piece, startTime: 0)
        e.handle(event: on(60, at: 1.0))
        XCTAssertNil(e.judgements[0])
        XCTAssertEqual(e.judgements[1], .perfect)
    }

    func test_isFinished_only_after_the_last_window_closes() {
        let e = PlayAlongEngine(piece: twoNotePiece(), startTime: 0)
        e.update(now: 1.0)
        XCTAssertFalse(e.isFinished)
        e.update(now: 1.300)
        XCTAssertTrue(e.isFinished)
    }
}

final class PlayAlongScoringTests: XCTestCase {

    /// Ten notes, one per second at 60bpm.
    private func tenNotePiece() -> LessonPiece {
        LessonPiece(id: "t", title: "T", bpm: 60, beatsPerBar: 4,
                    notes: (0..<10).map {
                        LessonNote(midiNote: 60, startBeat: Double($0), durationBeats: 1)
                    })
    }

    private func engineHittingAll(_ piece: LessonPiece, offset: TimeInterval) -> PlayAlongEngine {
        let e = PlayAlongEngine(piece: piece, startTime: 0)
        for note in piece.notes {
            e.handle(event: NoteEvent(midiNote: note.midiNote, velocity: 100, isOn: true,
                                      timestamp: piece.secondsForBeat(note.startBeat) + offset))
        }
        return e
    }

    func test_all_perfect_scores_full_accuracy_and_three_stars() {
        let result = engineHittingAll(tenNotePiece(), offset: 0).result()
        XCTAssertEqual(result.accuracy, 1.0, accuracy: 0.0001)
        XCTAssertEqual(result.stars, 3)
        XCTAssertEqual(result.perfect, 10)
    }

    func test_all_good_scores_seventy_percent() {
        let result = engineHittingAll(tenNotePiece(), offset: 0.100).result()
        XCTAssertEqual(result.accuracy, 0.7, accuracy: 0.0001)
        XCTAssertEqual(result.good, 10)
        XCTAssertEqual(result.stars, 0)
    }

    func test_all_missed_scores_zero() {
        let e = PlayAlongEngine(piece: tenNotePiece(), startTime: 0)
        e.update(now: 100)
        let result = e.result()
        XCTAssertEqual(result.accuracy, 0, accuracy: 0.0001)
        XCTAssertEqual(result.missed, 10)
        XCTAssertEqual(result.stars, 0)
    }

    func test_wrong_notes_apply_a_penalty() {
        let piece = tenNotePiece()
        let e = engineHittingAll(piece, offset: 0)
        e.handle(event: NoteEvent(midiNote: 71, velocity: 100, isOn: true, timestamp: 2.5))
        e.handle(event: NoteEvent(midiNote: 71, velocity: 100, isOn: true, timestamp: 3.5))
        let result = e.result()
        XCTAssertEqual(result.accuracy, 0.96, accuracy: 0.0001)
        XCTAssertEqual(result.wrongNotes, 2)
    }

    func test_penalty_cannot_drive_accuracy_below_zero() {
        let e = PlayAlongEngine(piece: tenNotePiece(), startTime: 0)
        e.update(now: 100)
        for i in 0..<100 {
            e.handle(event: NoteEvent(midiNote: 71, velocity: 100, isOn: true,
                                      timestamp: 0.5 + Double(i) * 0.01))
        }
        XCTAssertEqual(e.result().accuracy, 0, accuracy: 0.0001)
    }

    func test_exactly_eighty_percent_earns_one_star() {
        let piece = tenNotePiece()
        let e = PlayAlongEngine(piece: piece, startTime: 0)
        for note in piece.notes.prefix(8) {
            e.handle(event: NoteEvent(midiNote: note.midiNote, velocity: 100, isOn: true,
                                      timestamp: piece.secondsForBeat(note.startBeat)))
        }
        e.update(now: 100)
        let result = e.result()
        XCTAssertEqual(result.accuracy, 0.8, accuracy: 0.0001)
        XCTAssertEqual(result.stars, 1)
    }

    func test_empty_piece_scores_zero_without_dividing_by_zero() {
        let piece = LessonPiece(id: "e", title: "E", bpm: 60, beatsPerBar: 4, notes: [])
        let result = PlayAlongEngine(piece: piece, startTime: 0).result()
        XCTAssertEqual(result.accuracy, 0, accuracy: 0.0001)
        XCTAssertEqual(result.stars, 0)
    }

    func test_star_thresholds_match_the_curriculum_engine() {
        XCTAssertEqual(PlayAlongEngine.starThresholds, PassCriteria.standard.starThresholds)
    }
}
