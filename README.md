# Tonestep

An iOS music learning app: a graded ear-training curriculum plus MIDI play-along lessons.

Built with SwiftUI, SwiftData and AVFoundation. Targets iOS 17+.

## What's in it

**Graded curriculum** — 10 authored chapters generating 102 stages, running from
functional ear through intervals and harmony to a no-context "Free Field". Difficulty
scales along eight axes (content pool, answer-set size, harmonic context, voicing,
register, root policy, replays, deadline), and stage difficulty tracks *perceptual*
distance rather than item count: a pool of {P5, P4} is harder than {P5, m2} despite
being the same size.

Stages are generated from a per-chapter `DifficultyEnvelope` rather than hand-authored,
and sampling is deterministic — a given stage always presents the same drills.

**Play-Along** — piano lessons over CoreMIDI with an on-screen keyboard fallback.
Note onsets are judged against a beat-based score with perfect / good / late / missed
windows. Input and clock are both behind protocols, so the judging engine is pure and
fully unit-testable without MIDI hardware.

**15 training modules** — intervals, chords, scales, functional ear, progressions,
rhythm, melodic dictation, singing, and more.

**Spaced repetition** — SM-2, fed by every drill the user answers anywhere in the app.

## Building

Requires Xcode 16+ and [xcodegen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
open Tonestep.xcodeproj
```

The Xcode project is generated from `project.yml` and is not the source of truth —
run `xcodegen generate` after adding or removing files.

## Tests

```bash
xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,name=iPhone 17'
```

166 tests, covering the curriculum engine (determinism, difficulty monotonicity,
entitlement filtering, legacy `drillType` compatibility), the play-along judging
windows on both sides of every boundary, and the tone renderer.

## Layout

```
Tonestep/
  App/            entry point, root view
  Core/
    Audio/        AudioEngine, ToneRenderer, PitchDetector
    Curriculum/   chapters, stages, difficulty, progress
    PlayAlong/    note input, clock, judging engine
    Models/       music theory, drill results, user profile
    SpacedRepetition/
  Modules/        one folder per feature area (Today, Train, Journey, Learn, …)
  Resources/      assets and lesson content
TonestepTests/
docs/             GitHub Pages site, plus design specs and implementation plans
```

Design specs and implementation plans live in `docs/superpowers/`.

## Notes

Audio is synthesised per instrument (harmonic profile plus ADSR) because no soundfont
is bundled. Dropping a `GeneralUser_GS.sf2` into the bundle switches playback to it
automatically, using the correct General MIDI program per instrument.

Play-along content is original or public domain only.

## Licence

All rights reserved.
