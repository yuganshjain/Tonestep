import XCTest
@testable import EarIQ

final class NoteInputSourceTests: XCTestCase {
    func test_fake_source_forwards_events() {
        let source = FakeInputSource()
        var received: [NoteEvent] = []
        source.onEvent = { received.append($0) }
        source.start()

        let event = NoteEvent(midiNote: 60, velocity: 100, isOn: true, timestamp: 1.5)
        source.emit(event)

        XCTAssertEqual(received, [event])
    }

    func test_stopped_source_forwards_nothing() {
        let source = FakeInputSource()
        var received: [NoteEvent] = []
        source.onEvent = { received.append($0) }
        source.start()
        source.stop()
        source.emit(NoteEvent(midiNote: 60, velocity: 100, isOn: true, timestamp: 1))
        XCTAssertTrue(received.isEmpty)
    }

    func test_source_not_started_forwards_nothing() {
        let source = FakeInputSource()
        var received: [NoteEvent] = []
        source.onEvent = { received.append($0) }
        source.emit(NoteEvent(midiNote: 60, velocity: 100, isOn: true, timestamp: 1))
        XCTAssertTrue(received.isEmpty)
    }
}

final class PlaybackClockTests: XCTestCase {
    func test_fake_clock_starts_at_zero() {
        XCTAssertEqual(FakeClock().now, 0, accuracy: 0.0001)
    }

    func test_fake_clock_advances() {
        let clock = FakeClock()
        clock.advance(by: 1.25)
        clock.advance(by: 0.75)
        XCTAssertEqual(clock.now, 2.0, accuracy: 0.0001)
    }

    func test_system_clock_moves_forward() {
        let clock = SystemClock()
        let first = clock.now
        XCTAssertGreaterThanOrEqual(clock.now, first)
    }
}

final class LessonPieceTests: XCTestCase {

    func test_seconds_for_beat_at_120bpm() {
        let piece = LessonPiece(id: "t", title: "T", bpm: 120, beatsPerBar: 4,
                                notes: [LessonNote(midiNote: 60, startBeat: 0, durationBeats: 1)])
        XCTAssertEqual(piece.secondsForBeat(2), 1.0, accuracy: 0.0001)
    }

    func test_seconds_for_beat_at_60bpm() {
        let piece = LessonPiece(id: "t", title: "T", bpm: 60, beatsPerBar: 4,
                                notes: [LessonNote(midiNote: 60, startBeat: 0, durationBeats: 1)])
        XCTAssertEqual(piece.secondsForBeat(3), 3.0, accuracy: 0.0001)
    }

    func test_duration_covers_the_last_note() {
        let piece = LessonPiece(id: "t", title: "T", bpm: 60, beatsPerBar: 4, notes: [
            LessonNote(midiNote: 60, startBeat: 0, durationBeats: 1),
            LessonNote(midiNote: 62, startBeat: 4, durationBeats: 2)
        ])
        XCTAssertEqual(piece.duration, 6.0, accuracy: 0.0001)
    }

    func test_empty_piece_has_zero_duration() {
        let piece = LessonPiece(id: "t", title: "T", bpm: 60, beatsPerBar: 4, notes: [])
        XCTAssertEqual(piece.duration, 0, accuracy: 0.0001)
    }

    func test_library_loads_every_bundled_piece() {
        XCTAssertGreaterThanOrEqual(LessonLibrary.all.count, 3)
    }

    func test_every_bundled_piece_has_notes() {
        for piece in LessonLibrary.all {
            XCTAssertFalse(piece.notes.isEmpty, "\(piece.id) has no notes")
        }
    }

    func test_every_bundled_piece_has_positive_bpm() {
        for piece in LessonLibrary.all {
            XCTAssertGreaterThan(piece.bpm, 0, "\(piece.id) has non-positive bpm")
        }
    }

    func test_bundled_piece_notes_are_in_beat_order() {
        for piece in LessonLibrary.all {
            let beats = piece.notes.map(\.startBeat)
            XCTAssertEqual(beats, beats.sorted(), "\(piece.id) notes are out of order")
        }
    }

    func test_lookup_by_id() {
        XCTAssertNotNil(LessonLibrary.piece(id: "ode_to_joy"))
        XCTAssertNil(LessonLibrary.piece(id: "does_not_exist"))
    }
}
