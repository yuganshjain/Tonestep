# Graded Curriculum — Design

Date: 2026-08-09
Status: Approved for planning

## Problem

Tonestep ships 15 training modules — more breadth than most competitors. But there is no
difficulty or progression system anywhere in the codebase. A user's 200th interval drill is
statistically identical to their 1st.

This is the gap. Complete Ear Trainer's moat is its hundreds of graded levels; EarMaster sells
structured courses. Tonestep competes on neither. Adding a 16th module would widen a shallow app
rather than deepen it.

Two defects found while auditing reinforce the same conclusion:

1. `DailySessionBuilder.randomDrillType` (`Tonestep/Core/SpacedRepetition/SREngine.swift:103`)
   handles only four modules. All others fall through `default:` and return the hardcoded string
   `"interval_major_third_ascending"`. The Daily Session has never generated a drill for Rhythm,
   Melody, Jazz Chords, Absolute Pitch, or any other module.
2. Difficulty is currently approximated by paywall flags — `ChordQuality.isProOnly`,
   `ScaleType.freeForAll`. Monetisation state is standing in for pedagogy.

## Goals

- A single unified journey of graded stages, fitting the existing streak / Daily Session identity.
- Difficulty that scales along perceptual axes, not just item count.
- A stage schema that makes extending to the remaining 11 modules data work, not engineering.
- Replace the broken `randomDrillType` so Daily Session works for every module.

## Non-goals

- Bundling instrument audio. `AudioEngine.swift:36` looks for a `GeneralUser_GS.sf2` that does
  not exist in the repo, so all playback uses the default GM fallback, and the onboarding promise
  that instrument choice affects playback is currently unfulfilled. The `timbre` axis below is
  designed for it but ships inert. **This warrants its own spec immediately after this one.**
- The other 11 modules. Phase 2.
- Changing `TrainView`. Modules stay freely browsable for open practice; the journey never blocks
  practising anything.

## Scope

Phase 1 covers the progression engine plus four anchor modules: Interval Recognition, Chord
Recognition, Scale Recognition, Functional Ear. Enough to prove the curve end to end.

## Naming

`TonestepLevel` already means "XP level" (Level 1, "Tone Seeker"). Curriculum position is a separate
axis. Curriculum uses **Stage**; **Level** remains the XP cosmetic. These terms must not be mixed
in UI copy.

## Architecture

### Stage identity

Stage identity is `(chapterId, indexInChapter)`, serialised as `"\(chapterId)-\(indexInChapter)"`.

It is deliberately **not** a global integer. Phase 2 inserts chapters into the middle of the arc
(Inversions, Cadences); global integers would renumber every subsequent stage and silently
corrupt saved progress. The globally displayed stage number is computed from the current chapter
list at render time and never persisted.

### Supporting types

```swift
/// Union of everything a drill can ask about. Backed by the existing enums in MusicTheory.swift.
enum ContentItem: Hashable, Codable {
    case interval(Interval, IntervalDirection)
    case chord(ChordQuality)
    case scale(ScaleType)
    case degree(ScaleDegree)
}

/// Purchase state, resolved once from StoreManager.isPro at call sites.
/// Passed explicitly rather than read globally so CurriculumBuilder stays pure and testable.
enum Entitlement { case free, pro }
```

### DrillSpec

A drill is a parameterised spec, not a string. `drillType` is retained as the join key for
`DrillResult` and `SRItem` so no data migration is required, but it is now derived:

```swift
struct DrillSpec: Equatable {
    let module: TrainingModule
    let params: DifficultyParams
    var drillType: String   // derived; stable join key for SR + results
}
```

### DifficultyParams

```swift
struct DifficultyParams: Codable, Equatable {
    var contentPool: [ContentItem]       // intervals / chords / scales / degrees in play
    var answerSetSize: Int               // choices presented
    var harmonicContext: HarmonicContext // .cadencePrimer | .droneRoot | .isolated
    var voicings: Set<VoicingMode>       // .ascending | .descending | .harmonic
    var registerSpan: RegisterSpan       // .fixedMiddle | .twoOctaves | .threeOctaves
    var rootPolicy: RootPolicy           // .fixedC | .randomRoot
    var replaysAllowed: Int?             // nil = unlimited
    var responseDeadline: TimeInterval?  // nil = none
    var timbre: TimbreMode               // .primary | .mixed  (inert until audio spec)

    var difficultyScore: Double { get }  // weighted scalar, used for ordering + tests
}
```

Axis progression, easy to hard:

| Axis | Easy | Hard |
|---|---|---|
| Content pool | 2 items | full set |
| Confusability | far apart (P5 vs m2) | near neighbours (P5 vs P4) |
| Answer set | 2 choices | full set |
| Harmonic context | cadence primer | isolated, no key centre |
| Voicings | ascending only | + descending, + harmonic |
| Register | fixed octave | randomised across 3 |
| Root | always C | random root |
| Replays / deadline | unlimited, none | 0 replays, deadline set |

`randomRoot` matters more than it looks: fixing the root lets users answer from absolute pitch
memory rather than relative hearing, which defeats the exercise.

### ConfusionMatrix

```swift
enum ConfusionMatrix {
    static func confusability(_ a: ContentItem, _ b: ContentItem) -> Double  // 0...1
    static func poolDifficulty(_ pool: [ContentItem]) -> Double              // mean pairwise
}
```

This is the primary differentiator. Competitors scale difficulty by adding items; adding the
octave to a pool is trivial, adding the perfect 4th beside the perfect 5th is genuinely hard.
`poolDifficulty` feeds `difficultyScore` so the curve tracks perceptual distance.

### Chapter and Stage

```swift
struct Chapter: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let modules: [TrainingModule]
    let stageCount: Int
    let envelope: DifficultyEnvelope   // start + end params, interpolated across stageCount
    let isProOnly: Bool
}

struct Stage: Identifiable {
    var id: String { "\(chapterId)-\(indexInChapter)" }
    let chapterId: String
    let indexInChapter: Int
    let specs: [DrillSpec]
    let passCriteria: PassCriteria
}

struct PassCriteria {
    let minQuestions: Int      // 10
    let minAccuracy: Double    // 0.80 to pass
    let starThresholds: [Double] // [0.80, 0.90, 1.00] -> 1, 2, 3 stars
}
```

### CurriculumBuilder

```swift
enum CurriculumBuilder {
    static let chapters: [Chapter]
    static func chapters(for entitlement: Entitlement) -> [Chapter]
    static func stage(id: String, entitlement: Entitlement) -> Stage?
    static func drillSpecs(forStage id: String, entitlement: Entitlement, count: Int) -> [DrillSpec]
}
```

Generation is deterministic: the RNG is seeded from the stage id, so a given stage always yields
the same drills. Stages interpolate their params across the chapter's `DifficultyEnvelope`.

### StageEvaluator

```swift
enum StageEvaluator {
    static func evaluate(results: [DrillResult], criteria: PassCriteria) -> StageOutcome
}

struct StageOutcome {
    let passed: Bool
    let accuracy: Double
    let stars: Int
}
```

### JourneyProgress

New SwiftData models alongside the existing `DrillResult`, `DailySessionRecord`, `SRItem`:

```swift
@Model final class JourneyProgress {
    var currentChapterId: String
    var currentIndexInChapter: Int
    var lastUpdated: Date
}

@Model final class StageRecord {
    var stageId: String        // "\(chapterId)-\(indexInChapter)"
    var bestAccuracy: Double
    var stars: Int
    var passedAt: Date?
}
```

Both must be registered in the `modelContainer` call in `TonestepApp.swift`.

## Curriculum

Ten chapters, 102 stages. The arc runs functional to intervallic to harmonic to modal to
integrated.

Opening on functional ear rather than intervals is deliberate. It is what Functional Ear Trainer
proved works, and it is the skill that transfers to playing by ear. Most apps open with "here are
13 intervals, memorise them", which is where most users quit.

| # | Chapter | Modules | Stages | Focus | Pro |
|---|---|---|---|---|---|
| 1 | Finding Home | Functional Ear | 8 | Do, Sol, then Mi; cadence primer throughout | No |
| 2 | The Perfect Intervals | Intervals | 8 | P5, octave, then P4; ascending then descending | No |
| 3 | Major vs Minor | Intervals, Chords | 10 | m3/M3 and major/minor triads together | No |
| 4 | The Triad Family | Chords | 10 | add diminished, augmented | No |
| 5 | Steps and Leaps | Intervals | 12 | add 2nds, 6ths, 7ths, tritone | No |
| 6 | Hearing Function, Not Distance | Functional Ear | 12 | all 7 degrees; drone gives way to isolated | No |
| 7 | Scales and Modes | Scales | 10 | major, natural minor, pentatonics | No |
| 8 | Sevenths and Colour | Chords | 10 | dom7, maj7, min7, sus, add9 | Yes |
| 9 | Modal Colours | Scales | 10 | dorian, lydian, mixolydian, phrygian, locrian | Yes |
| 10 | Free Field | all four | 12 | full pools, isolated, random root, deadline | Yes |

Free users get chapters 1–7: 70 stages, a complete arc ending at a natural boundary.
Pro adds chapters 8–10: 32 further stages, 102 total.

Phase 2 inserts Inversions and Cadences chapters after chapter 8, plus the remaining modules.
Stage identity is designed to absorb that insertion without disturbing saved progress.

## Integration

- **`DailySessionBuilder`** — `randomDrillType` is deleted. Specs come from
  `CurriculumBuilder.drillSpecs(forStage:entitlement:count:)`. A session becomes: today's stage
  work, plus due SR items, plus weak spots. This fixes the four-module limitation.
- **Anchor module views** — `IntervalModuleView`, `ChordDrillView`, `ScaleDrillView`,
  `FunctionalEarDrillView` currently each roll their own randomisation. Each becomes a renderer
  accepting a `DrillSpec`. This is the largest change in the plan and the reason Phase 2 is data
  work rather than engineering.
- **`TodayView`** — Daily Session card surfaces current chapter and stage. The file is already
  420 lines and will grow; its card subviews are extracted to a sibling file in the same pass.
- **`JourneyView`** — new, in `Tonestep/Modules/Journey/`. Renders the path, chapter headers, stage
  states (locked / current / passed with stars).
- **`TrainView`** — unchanged.
- **`SREngine.grade`** — unchanged. Stage results continue to flow into it.

## Edge cases

**Paywall placement.** Gating individual pro content wherever it falls would drop a wall
mid-path. Instead `chapters(for:)` filters whole chapters, so free users reach a natural chapter
boundary rather than a dead end mid-arc. Individual pro content never appears inside a free
chapter.

**Existing users must not restart at zero.** `JourneySeeder.inferStartingStage(from:)` derives a
starting position from recorded `DrillResult` accuracy per module. Shipping without this would
read to existing users as a wipe of their progress.

**Empty stages.** A misconfigured envelope could yield a stage with no valid drills. Rejected at
build time via a validation pass over all chapters, covered by test.

**Abandoned stages.** Partial results are still written to SR; the stage is not marked passed and
`JourneyProgress` does not advance.

**Audio interruption.** Existing `AudioEngine` interruption handling applies unchanged.

## Testing

- `CurriculumBuilder` determinism: same stage id yields identical specs across runs.
- Monotonicity: `difficultyScore` is non-decreasing across stages within a chapter, and across
  chapters in order. This makes the curve verifiable rather than a matter of taste.
- Every stage yields at least one valid `DrillSpec`, under both free and pro entitlement.
- `drillType` round-trips: spec to string matches existing `SRItem` keys, confirming SR history
  survives.
- `StageEvaluator` pass/fail and star boundaries, including exact-threshold cases.
- `JourneySeeder` produces a sane starting stage from representative history, and stage 1 for
  empty history.
- Chapter insertion: adding a chapter mid-list leaves existing `StageRecord` ids resolvable.

## Files

New, `Tonestep/Core/Curriculum/`:
`DrillSpec.swift`, `DifficultyParams.swift`, `ConfusionMatrix.swift`, `Chapter.swift`,
`CurriculumBuilder.swift`, `StageEvaluator.swift`, `JourneyProgress.swift`, `JourneySeeder.swift`

New, `Tonestep/Modules/Journey/`: `JourneyView.swift`

Modified: `SREngine.swift` (remove `randomDrillType`, accept specs), the four anchor module
views, `TodayView.swift` (+ extracted cards file), `TonestepApp.swift` (model container).

## Follow-up specs

1. **Instrument audio.** Bundle a real soundfont, honour the onboarding instrument choice, and
   activate the `timbre` axis. Highest-value follow-up; the onboarding promise is unfulfilled
   until it lands.
2. **Phase 2 curriculum.** Inversions and Cadences chapters, then the remaining modules.
