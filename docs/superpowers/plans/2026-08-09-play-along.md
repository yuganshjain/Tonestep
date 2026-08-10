# Play-Along Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship one complete Play-Along piano lesson — MIDI or on-screen input, scrolling note lane, per-note judgement, scored result — to prove the core interaction feels good.

**Architecture:** Input and clock are abstracted behind protocols so `PlayAlongEngine` stays pure and testable without MIDI hardware (which the Simulator does not have). Tasks 1–6 are pure logic under full TDD. Tasks 7–9 are SwiftUI, verified visually in the Simulator via the on-screen keyboard.

**Tech Stack:** Swift 5.9, SwiftUI, CoreMIDI, XCTest, xcodegen.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-09-play-along-design.md`
- Judging is **onset-only**. Note-off events are ignored; the UI must say so.
- Note positions are in **beats**, converted with `seconds = startBeat * 60 / bpm`.
- Windows: perfect ≤50 ms, good ≤120 ms, late ≤250 ms, then missed. Window opens at `scheduled − 120 ms`, closes at `scheduled + 250 ms`.
- Scoring: perfect 100, good 70, late 40, missed 0; wrong-note penalty 20 each; accuracy floors at 0.
- Star thresholds are `[0.8, 0.9, 1.0]` — identical to `PassCriteria.standard`, so a star means the same thing across the app.
- Content is **original or public-domain only**. No licensed songs.
- **xcodegen:** run `xcodegen generate` after creating any file, before building.
- Simulator UDID: `907A43A4-894B-4875-A20B-660CFCB02AD0`.
- Test harness works as of commit `fd3b190`.

---

### Task 1: NoteEvent, NoteInputSource, FakeInputSource

**Files:**
- Create: `Tonestep/Core/PlayAlong/NoteEvent.swift`
- Create: `Tonestep/Core/PlayAlong/NoteInputSource.swift`
- Test: `TonestepTests/NoteInputSourceTests.swift`

**Interfaces:**
- Produces: `NoteEvent(midiNote:velocity:isOn:timestamp:)`; `NoteInputSource` protocol with `onEvent`, `start()`, `stop()`; `FakeInputSource` with `emit(_:)`.

- [ ] **Step 1: Write the failing test**

Create `TonestepTests/NoteInputSourceTests.swift`:

```swift
import XCTest
@testable import Tonestep

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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/NoteInputSourceTests 2>&1 | grep -E "error:|Executed [0-9]+ tests"
```
Expected: FAIL — `cannot find 'FakeInputSource' in scope`

- [ ] **Step 3a: Create NoteEvent**

Create `Tonestep/Core/PlayAlong/NoteEvent.swift`:

```swift
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
```

- [ ] **Step 3b: Create the protocol and fake**

Create `Tonestep/Core/PlayAlong/NoteInputSource.swift`:

```swift
import Foundation

protocol NoteInputSource: AnyObject {
    var onEvent: ((NoteEvent) -> Void)? { get set }
    func start()
    func stop()
}

/// Scripted source for unit tests. MIDI hardware does not exist in the Simulator,
/// so the engine is always tested through this.
final class FakeInputSource: NoteInputSource {
    var onEvent: ((NoteEvent) -> Void)?
    private var isRunning = false

    func start() { isRunning = true }
    func stop() { isRunning = false }

    func emit(_ event: NoteEvent) {
        guard isRunning else { return }
        onEvent?(event)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/NoteInputSourceTests 2>&1 | grep -E "Executed [0-9]+ tests|TEST"
```
Expected: `Executed 3 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Tonestep/Core/PlayAlong/ TonestepTests/NoteInputSourceTests.swift Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: add NoteEvent and NoteInputSource abstraction"
```

---

### Task 2: PlaybackClock

**Files:**
- Create: `Tonestep/Core/PlayAlong/PlaybackClock.swift`
- Test: `TonestepTests/PlaybackClockTests.swift`

**Interfaces:**
- Produces: `PlaybackClock` protocol with `now: TimeInterval`; `SystemClock`; `FakeClock` with `advance(by:)` and settable `now`.

- [ ] **Step 1: Write the failing test**

Create `TonestepTests/PlaybackClockTests.swift`:

```swift
import XCTest
@testable import Tonestep

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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/PlaybackClockTests 2>&1 | grep -E "error:|Executed [0-9]+ tests"
```
Expected: FAIL — `cannot find 'FakeClock' in scope`

- [ ] **Step 3: Write minimal implementation**

Create `Tonestep/Core/PlayAlong/PlaybackClock.swift`:

```swift
import Foundation
import QuartzCore

protocol PlaybackClock: AnyObject {
    var now: TimeInterval { get }
}

/// CACurrentMediaTime is monotonic and unaffected by wall-clock changes,
/// which NSDate is not.
final class SystemClock: PlaybackClock {
    var now: TimeInterval { CACurrentMediaTime() }
}

/// Deterministic clock so timing tests never depend on wall time.
final class FakeClock: PlaybackClock {
    var now: TimeInterval = 0
    func advance(by delta: TimeInterval) { now += delta }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/PlaybackClockTests 2>&1 | grep -E "Executed [0-9]+ tests|TEST"
```
Expected: `Executed 3 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Tonestep/Core/PlayAlong/PlaybackClock.swift TonestepTests/PlaybackClockTests.swift Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: add PlaybackClock abstraction with deterministic fake"
```

---

### Task 3: LessonPiece and bundled content

**Files:**
- Create: `Tonestep/Core/PlayAlong/LessonPiece.swift`
- Create: `Tonestep/Resources/Lessons/ode_to_joy.json`
- Create: `Tonestep/Resources/Lessons/twinkle.json`
- Create: `Tonestep/Resources/Lessons/mary_had_a_little_lamb.json`
- Modify: `project.yml` (bundle the Lessons folder as a resource)
- Test: `TonestepTests/LessonPieceTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `LessonNote`, `LessonPiece` with `.duration`, `.secondsForBeat(_:)`; `LessonLibrary.all`, `LessonLibrary.piece(id:)`.

All three pieces are traditional or Beethoven — public domain, no licensing exposure.

- [ ] **Step 1: Write the failing test**

Create `TonestepTests/LessonPieceTests.swift`:

```swift
import XCTest
@testable import Tonestep

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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/LessonPieceTests 2>&1 | grep -E "error:|Executed [0-9]+ tests"
```
Expected: FAIL — `cannot find 'LessonPiece' in scope`

- [ ] **Step 3a: Create the model and library**

Create `Tonestep/Core/PlayAlong/LessonPiece.swift`:

```swift
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
```

- [ ] **Step 3b: Create the three pieces**

Create `Tonestep/Resources/Lessons/ode_to_joy.json` (Beethoven, public domain):

```json
{
  "id": "ode_to_joy",
  "title": "Ode to Joy",
  "bpm": 90,
  "beatsPerBar": 4,
  "notes": [
    { "midiNote": 64, "startBeat": 0,  "durationBeats": 1 },
    { "midiNote": 64, "startBeat": 1,  "durationBeats": 1 },
    { "midiNote": 65, "startBeat": 2,  "durationBeats": 1 },
    { "midiNote": 67, "startBeat": 3,  "durationBeats": 1 },
    { "midiNote": 67, "startBeat": 4,  "durationBeats": 1 },
    { "midiNote": 65, "startBeat": 5,  "durationBeats": 1 },
    { "midiNote": 64, "startBeat": 6,  "durationBeats": 1 },
    { "midiNote": 62, "startBeat": 7,  "durationBeats": 1 },
    { "midiNote": 60, "startBeat": 8,  "durationBeats": 1 },
    { "midiNote": 60, "startBeat": 9,  "durationBeats": 1 },
    { "midiNote": 62, "startBeat": 10, "durationBeats": 1 },
    { "midiNote": 64, "startBeat": 11, "durationBeats": 1 },
    { "midiNote": 64, "startBeat": 12, "durationBeats": 1.5 },
    { "midiNote": 62, "startBeat": 13.5, "durationBeats": 0.5 },
    { "midiNote": 62, "startBeat": 14, "durationBeats": 2 }
  ]
}
```

Create `Tonestep/Resources/Lessons/twinkle.json` (traditional):

```json
{
  "id": "twinkle",
  "title": "Twinkle, Twinkle, Little Star",
  "bpm": 100,
  "beatsPerBar": 4,
  "notes": [
    { "midiNote": 60, "startBeat": 0,  "durationBeats": 1 },
    { "midiNote": 60, "startBeat": 1,  "durationBeats": 1 },
    { "midiNote": 67, "startBeat": 2,  "durationBeats": 1 },
    { "midiNote": 67, "startBeat": 3,  "durationBeats": 1 },
    { "midiNote": 69, "startBeat": 4,  "durationBeats": 1 },
    { "midiNote": 69, "startBeat": 5,  "durationBeats": 1 },
    { "midiNote": 67, "startBeat": 6,  "durationBeats": 2 },
    { "midiNote": 65, "startBeat": 8,  "durationBeats": 1 },
    { "midiNote": 65, "startBeat": 9,  "durationBeats": 1 },
    { "midiNote": 64, "startBeat": 10, "durationBeats": 1 },
    { "midiNote": 64, "startBeat": 11, "durationBeats": 1 },
    { "midiNote": 62, "startBeat": 12, "durationBeats": 1 },
    { "midiNote": 62, "startBeat": 13, "durationBeats": 1 },
    { "midiNote": 60, "startBeat": 14, "durationBeats": 2 }
  ]
}
```

Create `Tonestep/Resources/Lessons/mary_had_a_little_lamb.json` (traditional):

```json
{
  "id": "mary_had_a_little_lamb",
  "title": "Mary Had a Little Lamb",
  "bpm": 100,
  "beatsPerBar": 4,
  "notes": [
    { "midiNote": 64, "startBeat": 0,  "durationBeats": 1 },
    { "midiNote": 62, "startBeat": 1,  "durationBeats": 1 },
    { "midiNote": 60, "startBeat": 2,  "durationBeats": 1 },
    { "midiNote": 62, "startBeat": 3,  "durationBeats": 1 },
    { "midiNote": 64, "startBeat": 4,  "durationBeats": 1 },
    { "midiNote": 64, "startBeat": 5,  "durationBeats": 1 },
    { "midiNote": 64, "startBeat": 6,  "durationBeats": 2 },
    { "midiNote": 62, "startBeat": 8,  "durationBeats": 1 },
    { "midiNote": 62, "startBeat": 9,  "durationBeats": 1 },
    { "midiNote": 62, "startBeat": 10, "durationBeats": 2 },
    { "midiNote": 64, "startBeat": 12, "durationBeats": 1 },
    { "midiNote": 67, "startBeat": 13, "durationBeats": 1 },
    { "midiNote": 67, "startBeat": 14, "durationBeats": 2 }
  ]
}
```

- [ ] **Step 3c: Bundle the folder preserving its directory**

`Bundle.urls(forResourcesWithExtension:subdirectory:)` only finds files if the folder is bundled as a **folder reference**, not a group. In `project.yml`, inside the `Tonestep` target's `sources:` list, add:

```yaml
      - path: Tonestep/Resources/Lessons
        type: folder
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/LessonPieceTests 2>&1 | grep -E "Executed [0-9]+ tests|TEST"
```
Expected: `Executed 9 tests, with 0 failures`

If `test_library_loads_every_bundled_piece` fails with 0 pieces, the folder was bundled as a group rather than a folder reference — recheck Step 3c.

- [ ] **Step 5: Commit**

```bash
git add Tonestep/Core/PlayAlong/LessonPiece.swift Tonestep/Resources/Lessons/ TonestepTests/LessonPieceTests.swift project.yml Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: add LessonPiece model and three public-domain pieces"
```

---

### Task 4: PlayAlongEngine judging

**Files:**
- Create: `Tonestep/Core/PlayAlong/PlayAlongEngine.swift`
- Test: `TonestepTests/PlayAlongJudgingTests.swift`

**Interfaces:**
- Consumes: `LessonPiece`, `NoteEvent`.
- Produces: `Judgement` enum (`perfect`, `good`, `late`, `missed`); `PlayAlongEngine(piece:startTime:)` with `handle(event:)`, `update(now:)`, `judgements`, `wrongNoteCount`, `isFinished`.

This is the heart of the product. Every timing boundary is tested on both sides.

- [ ] **Step 1: Write the failing test**

Create `TonestepTests/PlayAlongJudgingTests.swift`:

```swift
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
        // Window opens at -0.120; this is before the first note's window entirely.
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
        // Same pitch at beat 0 (t=0) and beat 1 (t=1).
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/PlayAlongJudgingTests 2>&1 | grep -E "error:|Executed [0-9]+ tests"
```
Expected: FAIL — `cannot find 'PlayAlongEngine' in scope`

- [ ] **Step 3: Write minimal implementation**

Create `Tonestep/Core/PlayAlong/PlayAlongEngine.swift`:

```swift
import Foundation

enum Judgement: String, Equatable {
    case perfect, good, late, missed
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

    let piece: LessonPiece
    private let startTime: TimeInterval
    private let scheduled: [TimeInterval]

    private(set) var judgements: [Judgement?]
    private(set) var wrongNoteCount = 0

    init(piece: LessonPiece, startTime: TimeInterval) {
        self.piece = piece
        self.startTime = startTime
        self.scheduled = piece.notes.map { startTime + piece.secondsForBeat($0.startBeat) }
        self.judgements = Array(repeating: nil, count: piece.notes.count)
    }

    /// True once every note's window has closed.
    var isFinished: Bool {
        guard let last = scheduled.max() else { return true }
        return lastUpdate >= last + Self.lateWindow
    }

    private var lastUpdate: TimeInterval = -.infinity

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
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/PlayAlongJudgingTests 2>&1 | grep -E "Executed [0-9]+ tests|TEST"
```
Expected: `Executed 19 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Tonestep/Core/PlayAlong/PlayAlongEngine.swift TonestepTests/PlayAlongJudgingTests.swift Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: add PlayAlongEngine note judging"
```

---

### Task 5: Scoring and result

**Files:**
- Modify: `Tonestep/Core/PlayAlong/PlayAlongEngine.swift`
- Test: `TonestepTests/PlayAlongScoringTests.swift`

**Interfaces:**
- Produces: `PlayAlongResult(accuracy:stars:perfect:good:late:missed:wrongNotes:)`; `PlayAlongEngine.result() -> PlayAlongResult`.

- [ ] **Step 1: Write the failing test**

Create `TonestepTests/PlayAlongScoringTests.swift`:

```swift
import XCTest
@testable import Tonestep

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
        for (i, note) in piece.notes.enumerated() {
            _ = i
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
        // Two extra notes at a pitch not in the piece, during the piece.
        e.handle(event: NoteEvent(midiNote: 71, velocity: 100, isOn: true, timestamp: 2.5))
        e.handle(event: NoteEvent(midiNote: 71, velocity: 100, isOn: true, timestamp: 3.5))
        let result = e.result()
        // (1000 - 40) / 1000
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
        // Eight perfect, two missed => 800/1000.
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
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/PlayAlongScoringTests 2>&1 | grep -E "error:|Executed [0-9]+ tests"
```
Expected: FAIL — `value of type 'PlayAlongEngine' has no member 'result'`

Note: `test_star_thresholds_match_the_curriculum_engine` requires `PassCriteria` from the curriculum-engine plan. If that plan has not been executed yet, delete that one test and keep the literal `[0.8, 0.9, 1.0]` in the implementation.

- [ ] **Step 3: Add scoring to the engine**

Append to `PlayAlongEngine.swift`, inside the class:

```swift
    static let starThresholds: [Double] = [0.8, 0.9, 1.0]

    private static func points(for judgement: Judgement) -> Int {
        switch judgement {
        case .perfect: return 100
        case .good:    return 70
        case .late:    return 40
        case .missed:  return 0
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
```

And add at file scope, after the `Judgement` enum:

```swift
struct PlayAlongResult: Equatable {
    let accuracy: Double
    let stars: Int
    let perfect: Int
    let good: Int
    let late: Int
    let missed: Int
    let wrongNotes: Int
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/PlayAlongScoringTests 2>&1 | grep -E "Executed [0-9]+ tests|TEST"
```
Expected: `Executed 8 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Tonestep/Core/PlayAlong/PlayAlongEngine.swift TonestepTests/PlayAlongScoringTests.swift Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: add Play-Along scoring and result"
```

---

### Task 6: MIDIInputSource

**Files:**
- Create: `Tonestep/Core/PlayAlong/MIDIInputSource.swift`
- Modify: `project.yml` (add CoreMIDI framework)

**Interfaces:**
- Consumes: `NoteInputSource`, `NoteEvent`.
- Produces: `MIDIInputSource` conforming to `NoteInputSource`, plus `@Published var connectedDeviceName: String?`.

This adapter holds **no judging logic** and is not unit-tested — MIDI hardware does not exist in
the Simulator. It is verified manually on a device. Keeping it logic-free is what makes that
acceptable.

- [ ] **Step 1: Add the framework**

In `project.yml`, under the `Tonestep` target's `dependencies:`, add:

```yaml
      - sdk: CoreMIDI.framework
```

- [ ] **Step 2: Write the adapter**

Create `Tonestep/Core/PlayAlong/MIDIInputSource.swift`:

```swift
import Foundation
import CoreMIDI
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
            for word in withUnsafeBytes(of: packet.words, { $0.bindMemory(to: UInt32.self) })
                .prefix(Int(packet.wordCount)) {

                let status = UInt8((word >> 20) & 0xF)
                let note = UInt8((word >> 8) & 0x7F)
                let velocity = UInt8(word & 0x7F)

                // 0x9 = note on, 0x8 = note off. Note-on with velocity 0 is note-off.
                if status == 0x9 && velocity > 0 {
                    emit(NoteEvent(midiNote: note, velocity: velocity, isOn: true, timestamp: now))
                } else if status == 0x8 || (status == 0x9 && velocity == 0) {
                    emit(NoteEvent(midiNote: note, velocity: 0, isOn: false, timestamp: now))
                }
            }
            packet = MIDIEventPacketNext(&packet).pointee
        }
    }

    private func emit(_ event: NoteEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.onEvent?(event)
        }
    }
}
```

- [ ] **Step 3: Verify it compiles**

```bash
xcodegen generate && xcodebuild -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Confirm the suite still passes**

```bash
xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' 2>&1 | grep -E "Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)"
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add Tonestep/Core/PlayAlong/MIDIInputSource.swift project.yml Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: add CoreMIDI input source"
```

---

### Task 7: PianoKeyboardView and OnScreenInputSource

**Files:**
- Create: `Tonestep/Modules/PlayAlong/PianoKeyboardView.swift`

**Interfaces:**
- Consumes: `NoteInputSource`, `NoteEvent`, `Color.appPurple`.
- Produces: `OnScreenInputSource` conforming to `NoteInputSource` with `press(_:)`; `PianoKeyboardView(lowestNote:octaves:highlighted:source:)`.

This is what makes the whole feature developable in the Simulator, where no MIDI device exists.

- [ ] **Step 1: Write the view and source**

Create `Tonestep/Modules/PlayAlong/PianoKeyboardView.swift`:

```swift
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

    private var whiteOffsets: [Int] { [0, 2, 4, 5, 7, 9, 11] }
    private var blackOffsets: [Int] { [1, 3, 6, 8, 10] }

    private var whiteNotes: [UInt8] {
        (0..<octaves).flatMap { octave in
            whiteOffsets.map { UInt8(Int(lowestNote) + octave * 12 + $0) }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let whiteWidth = geo.size.width / CGFloat(whiteNotes.count)

            ZStack(alignment: .topLeading) {
                HStack(spacing: 1) {
                    ForEach(whiteNotes, id: \.self) { note in
                        Rectangle()
                            .fill(highlighted.contains(note) ? Color.appPurple.opacity(0.35) : Color.white)
                            .overlay(Rectangle().stroke(Color.black.opacity(0.15), lineWidth: 0.5))
                            .onTapGesture { source.press(note) }
                    }
                }

                ForEach(blackKeys(whiteWidth: whiteWidth), id: \.note) { key in
                    Rectangle()
                        .fill(highlighted.contains(key.note) ? Color.appPurple : Color.black)
                        .frame(width: whiteWidth * 0.6, height: geo.size.height * 0.62)
                        .offset(x: key.x)
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
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodegen generate && xcodebuild -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:"
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Tonestep/Modules/PlayAlong/PianoKeyboardView.swift Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: add on-screen piano keyboard input"
```

---

### Task 8: PlayAlongView

**Files:**
- Create: `Tonestep/Modules/PlayAlong/PlayAlongView.swift`

**Interfaces:**
- Consumes: `LessonPiece`, `PlayAlongEngine`, `MIDIInputSource`, `OnScreenInputSource`, `PianoKeyboardView`, `SystemClock`.
- Produces: `PlayAlongView(piece:)`.

- [ ] **Step 1: Write the view**

Create `Tonestep/Modules/PlayAlong/PlayAlongView.swift`:

```swift
import SwiftUI
import QuartzCore

struct PlayAlongView: View {
    let piece: LessonPiece

    @State private var engine: PlayAlongEngine?
    @State private var startTime: TimeInterval = 0
    @State private var now: TimeInterval = 0
    @State private var finished = false
    @StateObject private var midi = MIDIInputSource()
    @StateObject private var onScreen = OnScreenInputSource()

    /// Seconds of lead-in before the first note, and how much time the lane shows.
    private let countIn: TimeInterval = 2.0
    private let lookAhead: TimeInterval = 3.0

    private var elapsed: TimeInterval { now - startTime }

    private var expectedNow: Set<UInt8> {
        Set(piece.notes
            .filter { abs(piece.secondsForBeat($0.startBeat) - elapsed) < 0.35 }
            .map(\.midiNote))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            noteLane
            PianoKeyboardView(lowestNote: 60, octaves: 2,
                              highlighted: expectedNow, source: onScreen)
                .frame(height: 140)
                .padding(12)
        }
        .background(Color.appPurple.ignoresSafeArea())
        .onAppear(perform: begin)
        .onDisappear(perform: end)
        .fullScreenCover(isPresented: $finished) {
            if let result = engine?.result() {
                PlayAlongResultView(piece: piece, result: result)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(piece.title)
                .font(.headline).foregroundStyle(.white)
            Text(midi.connectedDeviceName ?? "Using on-screen keyboard")
                .font(.caption).foregroundStyle(.white.opacity(0.7))
            Text("Timing is scored on when you press, not how long you hold.")
                .font(.caption2).foregroundStyle(.white.opacity(0.55))
        }
        .padding(.vertical, 12)
    }

    /// Notes fall toward a fixed judgement line near the bottom.
    private var noteLane: some View {
        GeometryReader { geo in
            let lineY = geo.size.height * 0.82
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(height: 2)
                    .offset(y: lineY)

                ForEach(Array(piece.notes.enumerated()), id: \.offset) { index, note in
                    let due = piece.secondsForBeat(note.startBeat)
                    let delta = due - elapsed
                    if delta < lookAhead && delta > -0.6 {
                        let progress = 1 - (delta / lookAhead)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colour(for: engine?.judgements[index] ?? nil))
                            .frame(width: 42,
                                   height: max(18, CGFloat(note.durationBeats) * 26))
                            .position(
                                x: xPosition(for: note.midiNote, width: geo.size.width),
                                y: lineY * CGFloat(progress)
                            )
                    }
                }
            }
        }
    }

    private func colour(for judgement: Judgement?) -> Color {
        switch judgement {
        case .perfect: return .green
        case .good:    return .mint
        case .late:    return .orange
        case .missed:  return .red.opacity(0.6)
        case nil:      return .white.opacity(0.9)
        }
    }

    private func xPosition(for midiNote: UInt8, width: CGFloat) -> CGFloat {
        let lowest = piece.notes.map(\.midiNote).min() ?? 60
        let highest = piece.notes.map(\.midiNote).max() ?? 72
        let span = max(1, Int(highest) - Int(lowest))
        let t = CGFloat(Int(midiNote) - Int(lowest)) / CGFloat(span)
        return 30 + t * (width - 60)
    }

    private func begin() {
        let clock = SystemClock()
        startTime = clock.now + countIn
        now = clock.now
        let engine = PlayAlongEngine(piece: piece, startTime: startTime)
        self.engine = engine

        midi.onEvent = { engine.handle(event: $0) }
        onScreen.onEvent = { engine.handle(event: $0) }
        midi.start()
        onScreen.start()

        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            let t = clock.now
            now = t
            engine.update(now: t)
            if engine.isFinished {
                timer.invalidate()
                finished = true
            }
        }
    }

    private func end() {
        midi.stop()
        onScreen.stop()
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodegen generate && xcodebuild -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:"
```
Expected: `** BUILD SUCCEEDED **` (fails until Task 9 adds `PlayAlongResultView`; do Task 9 then rebuild)

- [ ] **Step 3: Commit after Task 9 builds clean**

---

### Task 9: Result screen and progress integration

**Files:**
- Create: `Tonestep/Modules/PlayAlong/PlayAlongResultView.swift`

**Interfaces:**
- Consumes: `LessonPiece`, `PlayAlongResult`, `DrillResult`, `TrainingModule`.
- Produces: `PlayAlongResultView(piece:result:)`.

Results are written as `DrillResult` so existing streaks, XP and progress keep working without
changes to those systems.

- [ ] **Step 1: Write the view**

Create `Tonestep/Modules/PlayAlong/PlayAlongResultView.swift`:

```swift
import SwiftUI
import SwiftData

struct PlayAlongResultView: View {
    let piece: LessonPiece
    let result: PlayAlongResult

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(piece.title)
                .font(.title2).fontWeight(.bold).foregroundStyle(.white)

            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < result.stars ? "star.fill" : "star")
                        .font(.system(size: 40))
                        .foregroundStyle(index < result.stars
                                         ? Color(red: 1, green: 0.85, blue: 0.2)
                                         : .white.opacity(0.3))
                }
            }

            Text("\(Int((result.accuracy * 100).rounded()))%")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                row("Perfect", result.perfect, .green)
                row("Good", result.good, .mint)
                row("Late", result.late, .orange)
                row("Missed", result.missed, .red)
                row("Wrong notes", result.wrongNotes, .red)
            }
            .padding(16)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 32)

            Spacer()

            Button { dismiss() } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Color.appPurple)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background(Color.appPurple.ignoresSafeArea())
        .onAppear(perform: record)
    }

    private func row(_ label: String, _ value: Int, _ colour: Color) -> some View {
        HStack {
            Circle().fill(colour).frame(width: 8, height: 8)
            Text(label).font(.subheadline).foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text("\(value)").font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
        }
    }

    /// Feed the existing progress systems so streaks and XP keep working.
    private func record() {
        let drill = DrillResult(
            module: .melodicDictation,
            drillType: "playalong_\(piece.id)",
            wasCorrect: result.accuracy >= 0.8,
            responseTime: piece.duration
        )
        context.insert(drill)
        try? context.save()
    }
}
```

- [ ] **Step 2: Build and run the whole suite**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' 2>&1 | grep -E "Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)|error:"
```
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 3: Verify by hand in the Simulator**

Launch the app, open a Play-Along lesson, and play along using the on-screen keyboard. Confirm:
notes scroll and reach the judgement line in time with the count-in; tapping a highlighted key
turns the note green; ignoring notes turns them red; the result screen shows a plausible score.

```bash
xcrun simctl launch 907A43A4-894B-4875-A20B-660CFCB02AD0 com.yugansh.Tonestep
```

- [ ] **Step 4: Commit**

```bash
git add Tonestep/Modules/PlayAlong/ Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: add Play-Along lesson view and result screen"
```

---

## Definition of done

- `xcodebuild test -scheme Tonestep` passes.
- A lesson is playable end to end in the Simulator using the on-screen keyboard.
- Every judging window is covered by a test on both sides of its boundary.
- `MIDIInputSource` contains no judging logic.
- No licensed content is bundled.

## Known gaps this slice does not close

- **Latency is unmeasured.** Display and input latency need measuring on a real device; the
  windows above may need tuning once you can feel it.
- **MIDI is unverified.** Requires a physical device and a keyboard.
- **Content does not scale.** Three public-domain melodies prove the mechanic and nothing more;
  the licensing question in the spec remains the largest business risk.

## Follow-on plans

1. Notation rendering.
2. Backing tracks and audio sync.
3. Microphone input as a fourth `NoteInputSource`.
4. Content pipeline and licensing.
