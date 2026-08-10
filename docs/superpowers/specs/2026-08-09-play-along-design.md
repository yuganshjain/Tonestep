# Play-Along — Design

Date: 2026-08-09
Status: Approved for planning

## Problem

The product direction is a Yousician-style instrument learning platform. That is eight
subsystems, of which three exist or are planned (curriculum engine, gamification, subscriptions)
and five do not (note detection, notation, content pipeline, backing tracks, backend).

Building any of the five before proving the core interaction is a bet on an unvalidated premise.
This spec covers one vertical slice that answers the only question that matters first: **does
playing along feel good?**

If it does, the remaining subsystems are worth building. If it does not — if latency or judging
feels wrong — that is worth learning for the cost of one feature rather than a year.

## Goals

- A complete Play-Along lesson: scrolling note lane, live input, per-note judgement, result.
- Piano input over MIDI, with an on-screen keyboard fallback.
- A judging engine that is pure and exhaustively testable.
- An input abstraction that microphone detection can later satisfy without engine changes.

## Non-goals

- **Sheet-music notation.** A scrolling note lane only. Engraving is its own subsystem.
- **Backing tracks.** Audio mixing and sync are deferred.
- **Microphone detection.** `PitchDetector` today is 85 lines of monophonic autocorrelation with
  no onset detection; it is not a play-along input. It becomes a fourth `NoteInputSource` later.
- **Other instruments.** Guitar needs onset detection and polyphonic transcription.
- **Licensed songs.** Content here is original or public-domain only. Licensing is unsolved and
  must be solved before this becomes a business, but it does not block this slice.
- **Backend, accounts, content delivery.**

## Constraint that shapes the architecture

**MIDI hardware does not exist in the iOS Simulator.** If the engine talked to CoreMIDI directly
it could be neither unit-tested nor developed without a keyboard attached. Therefore input is
abstracted behind a protocol and the on-screen keyboard is a first-class source, not a nicety.

## Architecture

```
NoteInputSource (protocol)
├── MIDIInputSource       CoreMIDI, real hardware
├── OnScreenInputSource   tappable keys, works in Simulator
└── FakeInputSource       scripted events, unit tests

PlaybackClock (protocol)
├── SystemClock           CACurrentMediaTime()
└── FakeClock             steps deterministically in tests

PlayAlongEngine           pure; consumes events + time, emits judgements
```

### Core types

```swift
struct NoteEvent: Equatable {
    let midiNote: UInt8
    let velocity: UInt8
    let isOn: Bool
    let timestamp: TimeInterval   // seconds on the same clock as the engine
}

protocol NoteInputSource: AnyObject {
    var onEvent: ((NoteEvent) -> Void)? { get set }
    func start()
    func stop()
}

protocol PlaybackClock {
    var now: TimeInterval { get }
}
```

### Content

```swift
struct LessonNote: Codable, Equatable {
    let midiNote: UInt8
    let startBeat: Double
    let durationBeats: Double
}

struct LessonPiece: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let bpm: Double
    let beatsPerBar: Int
    let notes: [LessonNote]
}
```

Positions are in **beats, not seconds**, so tempo can change without rewriting content — needed
for the practice-slower feature that every app in this category has.

Seconds for note at index `i`: `notes[i].startBeat * 60 / bpm`.

### Judging

Onsets only. Note-off events are ignored in this slice; duration accuracy is a later concern.
This must be stated in the UI so users are not scored on something invisible to them.

Windows, relative to a note's scheduled time:

| Judgement | Condition |
|---|---|
| `perfect` | \|Δ\| ≤ 50 ms |
| `good` | 50 ms < \|Δ\| ≤ 120 ms |
| `late` | 120 ms < Δ ≤ 250 ms |
| `missed` | no matching note-on by scheduled + 250 ms |
| `wrongNote` | a note-on matching no open expected note |

A note's window opens at `scheduled − 120 ms` and closes at `scheduled + 250 ms`.

Matching a note-on at time `t`, pitch `p`:
1. Collect unjudged expected notes with pitch `p` whose window contains `t`.
2. Choose the one minimising `|t − scheduled|`.
3. If none, record a `wrongNote`.

Chords fall out of this for free: simultaneous notes share a `startBeat` and are matched
independently by pitch. Repeated notes of the same pitch are disambiguated by the
nearest-scheduled rule.

Events arriving before the first note's window opens are **ignored, not penalised** — users
noodle before starting, and punishing that feels broken.

### Scoring

```
points: perfect 100, good 70, late 40, missed 0
earned   = Σ points over expected notes
possible = 100 × expectedNotes.count
penalty  = 20 × wrongNoteCount
accuracy = max(0, earned − penalty) / possible
```

Stars use the same thresholds as the curriculum engine — `[0.8, 0.9, 1.0]` — so the two systems
stay consistent and a "3-star" means the same thing everywhere.

### Engine surface

```swift
final class PlayAlongEngine {
    init(piece: LessonPiece, startTime: TimeInterval)
    func handle(event: NoteEvent)
    func update(now: TimeInterval)        // closes windows, marks misses
    var judgements: [Judgement?] { get }   // parallel to piece.notes
    var wrongNoteCount: Int { get }
    var isFinished: Bool { get }
    func result() -> PlayAlongResult
}

struct PlayAlongResult: Equatable {
    let accuracy: Double
    let stars: Int
    let perfect: Int, good: Int, late: Int, missed: Int, wrongNotes: Int
}
```

## UI

- **`PlayAlongView`** — note lane scrolling toward a fixed judgement line; each note lights by
  judgement as it resolves; count-in bars before the first note.
- **`PianoKeyboardView`** — two octaves, highlights expected notes and lights keys as played.
  Doubles as `OnScreenInputSource`.
- **Result screen** — accuracy, stars, and the per-judgement breakdown.
- **Device status** — shows the connected MIDI device name, or "Using on-screen keyboard".

## Integration

- Results write a `DrillResult` so existing streaks, XP and progress keep working.
- Stars are computed with the curriculum thresholds.
- No changes to the curriculum engine in this slice. Once both exist, `ContentItem` gains a
  `.play(pieceId:)` case so lessons can appear inside curriculum stages.

## Edge cases

- **No MIDI device.** On-screen keyboard is used; the app never blocks on hardware.
- **Device connects or disconnects mid-lesson.** `MIDIInputSource` re-scans sources on CoreMIDI
  setup-change notifications; the lesson continues on whatever source remains.
- **Events with hardware timestamps.** CoreMIDI timestamps are mach absolute time; they are
  converted to the engine's clock domain once, at the adapter boundary.
- **Piece with no notes.** Rejected at load; a test asserts every bundled piece has ≥1 note.
- **App backgrounded mid-lesson.** The lesson is abandoned, not scored — partial timing data
  after a suspension is meaningless.
- **Sustained/held notes.** Only the onset is judged; releases are ignored.

## Testing

`PlayAlongEngine` is pure and carries the coverage, driven by `FakeInputSource` and `FakeClock`:

- Each window boundary exactly — 50 ms and 120 ms and 250 ms, on both sides.
- Wrong note, extra note, missed note.
- Chords: simultaneous expected notes judged independently.
- Repeated same-pitch notes matched to the nearest scheduled.
- Events before the piece starts are ignored, not penalised.
- Scoring arithmetic, including the wrong-note penalty flooring at zero.
- A perfect run yields 3 stars; a run at exactly 0.8 accuracy yields 1.

`MIDIInputSource` holds no logic and is verified manually on a device.
Every bundled `LessonPiece` JSON is asserted to parse and to contain at least one note.

## Files

New, `EarIQ/Core/PlayAlong/`: `NoteEvent.swift`, `NoteInputSource.swift`, `PlaybackClock.swift`,
`LessonPiece.swift`, `PlayAlongEngine.swift`, `MIDIInputSource.swift`

New, `EarIQ/Modules/PlayAlong/`: `PlayAlongView.swift`, `PianoKeyboardView.swift`,
`PlayAlongResultView.swift`

New, `EarIQ/Resources/Lessons/`: 5–8 `.json` pieces, original or public-domain.

Modified: `project.yml` (CoreMIDI framework), `EarIQ/Info.plist` via project.yml if Bluetooth
MIDI is enabled later.

## Open question to resolve before this becomes a business

**Song licensing.** Original and public-domain content proves the mechanic but will not retain
users, who want recognisable songs. The realistic options are user-supplied local audio,
commissioned originals, or negotiated publishing licences. This must be decided before scaling
content, and it is the single largest business risk in the whole direction.

## Follow-on specs

1. Notation rendering.
2. Backing tracks and audio sync.
3. Microphone input as a fourth `NoteInputSource` (guitar, voice).
4. Content pipeline and licensing.
