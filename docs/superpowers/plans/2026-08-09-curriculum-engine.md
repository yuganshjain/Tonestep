# Curriculum Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure-logic curriculum engine that turns 10 authored chapters into 102 graded stages of drills, with verifiable difficulty ordering.

**Architecture:** `DifficultyParams` describes the *space* a stage draws from; `DrillSpec` is a *resolved instance* sampled from that space by `CurriculumBuilder` using a seeded RNG. Chapters declare a `DifficultyEnvelope` that is interpolated across their stages, so 102 stages come from ~150 lines of authored data. No UI in this plan.

**Tech Stack:** Swift 5.9, SwiftData, XCTest, xcodegen.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-09-graded-curriculum-design.md`
- Phase 1 covers four anchor modules only: `.intervalRecognition`, `.chordRecognition`, `.scaleRecognition`, `.functionalEar`.
- Stage identity is `"\(chapterId)-\(indexInChapter)"`, never a global integer.
- `indexInChapter` is 0-based internally. Any user-facing number is computed at render time.
- Curriculum position is called **Stage**. `TonestepLevel` keeps the word **Level** for XP. Never mix these terms.
- `drillType` strings must match the legacy formats already in `SRItem`/`DrillResult`, so spaced-repetition history survives: `interval_major_3rd_ascending`, `chord_major`, `scale_natural_minor`, `functional_degree_do`.
- Free entitlement yields 70 stages (chapters 1–7). Pro yields 102 (all 10).
- All new engine files live in `Tonestep/Core/Curriculum/`.
- **xcodegen:** new files are picked up by path, so run `xcodegen generate` after creating any file and before building.
- Simulator UDID for all test commands: `907A43A4-894B-4875-A20B-660CFCB02AD0`.

## Prerequisite (already complete)

`TonestepTests` had no Info.plist and no `GENERATE_INFOPLIST_FILE`, so `xcodebuild test` failed at code signing and never ran a test. Fixed in commit `fd3b190`; 11 existing tests now pass. Verify before starting:

```bash
xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' 2>&1 | grep -E "Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)"
```
Expected: `Executed 11 tests, with 0 failures` and `** TEST SUCCEEDED **`

## Deviations from the spec (deliberate)

1. **`DrillSpec` no longer carries `DifficultyParams`.** The spec had `DrillSpec { module, params, drillType }`, but a `params` block describes a *set* of possible drills, which makes `drillType` ambiguous — you cannot derive "which interval" from "the pool of intervals". Split into `DifficultyParams` (the space, held by `Stage`) and `DrillSpec` (one resolved question).
2. **`ContentItem.interval` does not embed direction.** Direction comes from `VoicingMode` on the resolved `DrillSpec`, otherwise direction would be specified twice and could disagree.
3. **Cross-chapter monotonicity is not asserted.** The spec asked for non-decreasing difficulty across chapters, but a new chapter legitimately introduces new content at lower difficulty than the end of the previous one. Task 7 asserts within-chapter monotonicity (guaranteed by construction) plus Free Field outranking Finding Home.

---

### Task 1: ContentItem and Entitlement

**Files:**
- Create: `Tonestep/Core/Curriculum/ContentItem.swift`
- Test: `TonestepTests/ContentItemTests.swift`

**Interfaces:**
- Consumes: `Interval`, `ChordQuality`, `ScaleType`, `ScaleDegree`, `TrainingModule` (existing).
- Produces: `ContentItem` with `.drillType`, `.displayName`, `.module`, `.semitones`; `Entitlement` with `.free`, `.pro`.

- [ ] **Step 1: Write the failing test**

Create `TonestepTests/ContentItemTests.swift`:

```swift
import XCTest
@testable import Tonestep

final class ContentItemTests: XCTestCase {
    func test_interval_drillType_matches_legacy_format() {
        XCTAssertEqual(ContentItem.interval(.majorThird).drillType, "interval_major_3rd")
    }

    func test_chord_drillType_matches_legacy_format() {
        XCTAssertEqual(ContentItem.chord(.major).drillType, "chord_major")
    }

    func test_scale_drillType_matches_legacy_format() {
        XCTAssertEqual(ContentItem.scale(.naturalMinor).drillType, "scale_natural_minor")
    }

    func test_degree_drillType_matches_legacy_format() {
        XCTAssertEqual(ContentItem.degree(.do_).drillType, "functional_degree_do")
    }

    func test_module_mapping() {
        XCTAssertEqual(ContentItem.interval(.perfectFifth).module, .intervalRecognition)
        XCTAssertEqual(ContentItem.chord(.minor).module, .chordRecognition)
        XCTAssertEqual(ContentItem.scale(.major).module, .scaleRecognition)
        XCTAssertEqual(ContentItem.degree(.sol).module, .functionalEar)
    }

    func test_displayName() {
        XCTAssertEqual(ContentItem.interval(.perfectFifth).displayName, "Perfect 5th")
        XCTAssertEqual(ContentItem.degree(.sol).displayName, "Sol")
    }

    func test_semitones() {
        XCTAssertEqual(ContentItem.interval(.perfectFifth).semitones, [7])
        XCTAssertEqual(ContentItem.chord(.major).semitones, [0, 4, 7])
        XCTAssertEqual(ContentItem.degree(.sol).semitones, [7])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/ContentItemTests 2>&1 | grep -E "error:|Executed [0-9]+ tests"
```
Expected: FAIL — `cannot find 'ContentItem' in scope`

- [ ] **Step 3: Write minimal implementation**

Create `Tonestep/Core/Curriculum/ContentItem.swift`:

```swift
import Foundation

/// Everything a drill can ask the user to identify.
/// Backed by the existing enums in MusicTheory.swift.
enum ContentItem: Hashable, Codable {
    case interval(Interval)
    case chord(ChordQuality)
    case scale(ScaleType)
    case degree(ScaleDegree)

    /// Join key for DrillResult and SRItem. Must match the legacy string formats
    /// already persisted, or spaced-repetition history stops matching.
    var drillType: String {
        switch self {
        case .interval(let i): return i.drillType
        case .chord(let c):    return c.drillType
        case .scale(let s):    return s.drillType
        case .degree(let d):   return d.drillType
        }
    }

    var displayName: String {
        switch self {
        case .interval(let i): return i.name
        case .chord(let c):    return c.rawValue
        case .scale(let s):    return s.rawValue
        case .degree(let d):   return d.solfege
        }
    }

    var module: TrainingModule {
        switch self {
        case .interval: return .intervalRecognition
        case .chord:    return .chordRecognition
        case .scale:    return .scaleRecognition
        case .degree:   return .functionalEar
        }
    }

    /// Semitone content, used by ConfusionMatrix to measure perceptual similarity.
    var semitones: [Int] {
        switch self {
        case .interval(let i): return [i.rawValue]
        case .chord(let c):    return c.semitones
        case .scale(let s):    return s.semitones
        case .degree(let d):   return [d.semitoneFromRoot]
        }
    }
}

/// Purchase state. Passed explicitly rather than read from StoreManager so the
/// curriculum stays pure and testable.
enum Entitlement {
    case free, pro
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/ContentItemTests 2>&1 | grep -E "Executed [0-9]+ tests|TEST"
```
Expected: `Executed 7 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Tonestep/Core/Curriculum/ContentItem.swift TonestepTests/ContentItemTests.swift project.yml Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: add ContentItem and Entitlement for curriculum engine"
```

---

### Task 2: ConfusionMatrix

**Files:**
- Create: `Tonestep/Core/Curriculum/ConfusionMatrix.swift`
- Test: `TonestepTests/ConfusionMatrixTests.swift`

**Interfaces:**
- Consumes: `ContentItem` from Task 1.
- Produces: `ConfusionMatrix.confusability(_:_:) -> Double` (0...1) and `ConfusionMatrix.poolDifficulty(_:) -> Double` (0...1).

This is the differentiator: difficulty tracks perceptual distance, not item count. A pool of {P5, P4} is harder than {P5, m2} despite being the same size.

- [ ] **Step 1: Write the failing test**

Create `TonestepTests/ConfusionMatrixTests.swift`:

```swift
import XCTest
@testable import Tonestep

final class ConfusionMatrixTests: XCTestCase {
    func test_near_intervals_more_confusable_than_far() {
        let near = ConfusionMatrix.confusability(.interval(.perfectFifth), .interval(.perfectFourth))
        let far  = ConfusionMatrix.confusability(.interval(.perfectFifth), .interval(.minorSecond))
        XCTAssertGreaterThan(near, far)
    }

    func test_confusability_is_symmetric() {
        let a = ConfusionMatrix.confusability(.chord(.major), .chord(.minor))
        let b = ConfusionMatrix.confusability(.chord(.minor), .chord(.major))
        XCTAssertEqual(a, b, accuracy: 0.0001)
    }

    func test_identical_items_are_maximally_confusable() {
        XCTAssertEqual(ConfusionMatrix.confusability(.chord(.major), .chord(.major)), 1.0, accuracy: 0.0001)
    }

    func test_different_kinds_are_not_confusable() {
        XCTAssertEqual(ConfusionMatrix.confusability(.chord(.major), .interval(.perfectFifth)), 0.0, accuracy: 0.0001)
    }

    func test_major_minor_more_confusable_than_major_diminished() {
        let mm = ConfusionMatrix.confusability(.chord(.major), .chord(.minor))
        let md = ConfusionMatrix.confusability(.chord(.major), .chord(.diminished))
        XCTAssertGreaterThan(mm, md)
    }

    func test_poolDifficulty_higher_for_confusable_pool() {
        let hard = ConfusionMatrix.poolDifficulty([.interval(.perfectFifth), .interval(.perfectFourth)])
        let easy = ConfusionMatrix.poolDifficulty([.interval(.perfectFifth), .interval(.minorSecond)])
        XCTAssertGreaterThan(hard, easy)
    }

    func test_poolDifficulty_of_single_item_is_zero() {
        XCTAssertEqual(ConfusionMatrix.poolDifficulty([.interval(.perfectFifth)]), 0.0, accuracy: 0.0001)
    }

    func test_poolDifficulty_of_empty_pool_is_zero() {
        XCTAssertEqual(ConfusionMatrix.poolDifficulty([]), 0.0, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/ConfusionMatrixTests 2>&1 | grep -E "error:|Executed [0-9]+ tests"
```
Expected: FAIL — `cannot find 'ConfusionMatrix' in scope`

- [ ] **Step 3: Write minimal implementation**

Create `Tonestep/Core/Curriculum/ConfusionMatrix.swift`:

```swift
import Foundation

/// Measures how easily two items are mistaken for each other by ear.
/// Difficulty should track perceptual distance, not item count: adding the
/// octave to a pool is trivial, adding the perfect 4th beside the perfect 5th
/// is genuinely hard.
enum ConfusionMatrix {

    /// 0 = never confused, 1 = identical.
    static func confusability(_ a: ContentItem, _ b: ContentItem) -> Double {
        guard sameKind(a, b) else { return 0 }
        if a == b { return 1 }

        switch (a, b) {
        case (.interval(let x), .interval(let y)):
            return 1.0 - Double(abs(x.rawValue - y.rawValue)) / 12.0
        case (.degree(let x), .degree(let y)):
            return 1.0 - Double(abs(x.semitoneFromRoot - y.semitoneFromRoot)) / 11.0
        default:
            // Chords and scales are sets of pitches: Jaccard similarity.
            return jaccard(Set(a.semitones), Set(b.semitones))
        }
    }

    /// Mean pairwise confusability across the pool. 0 for pools of 0 or 1.
    static func poolDifficulty(_ pool: [ContentItem]) -> Double {
        guard pool.count > 1 else { return 0 }
        var total = 0.0
        var pairs = 0
        for i in 0..<pool.count {
            for j in (i + 1)..<pool.count {
                total += confusability(pool[i], pool[j])
                pairs += 1
            }
        }
        return pairs == 0 ? 0 : total / Double(pairs)
    }

    private static func jaccard(_ a: Set<Int>, _ b: Set<Int>) -> Double {
        let union = a.union(b)
        guard !union.isEmpty else { return 0 }
        return Double(a.intersection(b).count) / Double(union.count)
    }

    private static func sameKind(_ a: ContentItem, _ b: ContentItem) -> Bool {
        switch (a, b) {
        case (.interval, .interval), (.chord, .chord),
             (.scale, .scale), (.degree, .degree):
            return true
        default:
            return false
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/ConfusionMatrixTests 2>&1 | grep -E "Executed [0-9]+ tests|TEST"
```
Expected: `Executed 8 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Tonestep/Core/Curriculum/ConfusionMatrix.swift TonestepTests/ConfusionMatrixTests.swift Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: add ConfusionMatrix for perceptual difficulty weighting"
```

---

### Task 3: DifficultyParams and its axis enums

**Files:**
- Create: `Tonestep/Core/Curriculum/DifficultyParams.swift`
- Test: `TonestepTests/DifficultyParamsTests.swift`

**Interfaces:**
- Consumes: `ContentItem`, `ConfusionMatrix`.
- Produces: `HarmonicContext`, `VoicingMode`, `RegisterSpan`, `RootPolicy`, `TimbreMode`, `DifficultyParams` with `.difficultyScore: Double`.

- [ ] **Step 1: Write the failing test**

Create `TonestepTests/DifficultyParamsTests.swift`:

```swift
import XCTest
@testable import Tonestep

final class DifficultyParamsTests: XCTestCase {

    private func baseline() -> DifficultyParams {
        DifficultyParams(
            contentPool: [.interval(.perfectFifth), .interval(.octave)],
            answerSetSize: 2,
            harmonicContext: .cadencePrimer,
            voicings: [.ascending],
            registerSpan: .fixedMiddle,
            rootPolicy: .fixedC,
            replaysAllowed: nil,
            responseDeadline: nil,
            timbre: .primary
        )
    }

    func test_larger_pool_scores_higher() {
        var bigger = baseline()
        bigger.contentPool = [.interval(.perfectFifth), .interval(.octave), .interval(.majorThird)]
        XCTAssertGreaterThan(bigger.difficultyScore, baseline().difficultyScore)
    }

    func test_isolated_context_scores_higher_than_primer() {
        var harder = baseline()
        harder.harmonicContext = .isolated
        XCTAssertGreaterThan(harder.difficultyScore, baseline().difficultyScore)
    }

    func test_random_root_scores_higher_than_fixed() {
        var harder = baseline()
        harder.rootPolicy = .randomRoot
        XCTAssertGreaterThan(harder.difficultyScore, baseline().difficultyScore)
    }

    func test_more_voicings_score_higher() {
        var harder = baseline()
        harder.voicings = [.ascending, .descending, .harmonic]
        XCTAssertGreaterThan(harder.difficultyScore, baseline().difficultyScore)
    }

    func test_wider_register_scores_higher() {
        var harder = baseline()
        harder.registerSpan = .threeOctaves
        XCTAssertGreaterThan(harder.difficultyScore, baseline().difficultyScore)
    }

    func test_deadline_scores_higher() {
        var harder = baseline()
        harder.responseDeadline = 8
        XCTAssertGreaterThan(harder.difficultyScore, baseline().difficultyScore)
    }

    func test_fewer_replays_score_higher() {
        var harder = baseline()
        harder.replaysAllowed = 0
        XCTAssertGreaterThan(harder.difficultyScore, baseline().difficultyScore)
    }

    func test_confusable_pool_scores_higher_than_distant_pool_of_same_size() {
        var confusable = baseline()
        confusable.contentPool = [.interval(.perfectFifth), .interval(.perfectFourth)]
        var distant = baseline()
        distant.contentPool = [.interval(.perfectFifth), .interval(.minorSecond)]
        XCTAssertGreaterThan(confusable.difficultyScore, distant.difficultyScore)
    }

    func test_fixedMiddle_register_is_single_note() {
        XCTAssertEqual(RegisterSpan.fixedMiddle.midiRange, 60...60)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/DifficultyParamsTests 2>&1 | grep -E "error:|Executed [0-9]+ tests"
```
Expected: FAIL — `cannot find 'DifficultyParams' in scope`

- [ ] **Step 3: Write minimal implementation**

Create `Tonestep/Core/Curriculum/DifficultyParams.swift`:

```swift
import Foundation

enum HarmonicContext: String, Codable, CaseIterable {
    /// Play a I-IV-V-I cadence first so the key centre is established.
    case cadencePrimer
    /// Sustain the root underneath.
    case droneRoot
    /// No reference at all.
    case isolated

    var difficultyWeight: Double {
        switch self {
        case .cadencePrimer: return 0
        case .droneRoot:     return 4
        case .isolated:      return 9
        }
    }
}

enum VoicingMode: String, Codable, CaseIterable, Comparable {
    case ascending, descending, harmonic

    /// Suffix used in legacy drillType strings, e.g. interval_major_3rd_ascending.
    var legacySuffix: String { rawValue }

    static func < (lhs: VoicingMode, rhs: VoicingMode) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum RegisterSpan: String, Codable, CaseIterable {
    case fixedMiddle, twoOctaves, threeOctaves

    var midiRange: ClosedRange<UInt8> {
        switch self {
        case .fixedMiddle:  return 60...60
        case .twoOctaves:   return 52...76
        case .threeOctaves: return 45...81
        }
    }

    var difficultyWeight: Double {
        switch self {
        case .fixedMiddle:  return 0
        case .twoOctaves:   return 3
        case .threeOctaves: return 6
        }
    }
}

enum RootPolicy: String, Codable, CaseIterable {
    /// Always C. Lets users answer from absolute memory.
    case fixedC
    /// Randomised, which forces genuinely relative hearing.
    case randomRoot
}

enum TimbreMode: String, Codable, CaseIterable {
    case primary, mixed
}

/// Describes the *space* of drills a stage draws from.
/// A single resolved question is a DrillSpec, sampled from this.
struct DifficultyParams: Codable, Equatable {
    var contentPool: [ContentItem]
    var answerSetSize: Int
    var harmonicContext: HarmonicContext
    var voicings: Set<VoicingMode>
    var registerSpan: RegisterSpan
    var rootPolicy: RootPolicy
    var replaysAllowed: Int?      // nil = unlimited
    var responseDeadline: TimeInterval?  // nil = untimed
    var timbre: TimbreMode

    /// Scalar used to order stages and to assert the curve is monotonic in tests.
    /// Weights are tuned so no single axis dominates.
    var difficultyScore: Double {
        var score = 0.0
        score += ConfusionMatrix.poolDifficulty(contentPool) * 30
        score += Double(contentPool.count) * 1.5
        score += Double(answerSetSize) * 1.0
        score += harmonicContext.difficultyWeight
        score += Double(voicings.count) * 3
        score += registerSpan.difficultyWeight
        score += rootPolicy == .randomRoot ? 6 : 0
        if let replays = replaysAllowed {
            score += Double(max(0, 3 - replays)) * 2
        }
        score += responseDeadline != nil ? 5 : 0
        score += timbre == .mixed ? 4 : 0
        return score
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/DifficultyParamsTests 2>&1 | grep -E "Executed [0-9]+ tests|TEST"
```
Expected: `Executed 9 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Tonestep/Core/Curriculum/DifficultyParams.swift TonestepTests/DifficultyParamsTests.swift Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: add DifficultyParams with scalar difficulty score"
```

---

### Task 4: DrillSpec

**Files:**
- Create: `Tonestep/Core/Curriculum/DrillSpec.swift`
- Test: `TonestepTests/DrillSpecTests.swift`

**Interfaces:**
- Consumes: `ContentItem`, `VoicingMode`, `HarmonicContext`.
- Produces: `DrillSpec(module:item:voicing:rootMidi:choices:harmonicContext:replaysAllowed:responseDeadline:)` with `.drillType: String`.

- [ ] **Step 1: Write the failing test**

Create `TonestepTests/DrillSpecTests.swift`:

```swift
import XCTest
@testable import Tonestep

final class DrillSpecTests: XCTestCase {

    private func spec(item: ContentItem, voicing: VoicingMode) -> DrillSpec {
        DrillSpec(
            module: item.module,
            item: item,
            voicing: voicing,
            rootMidi: 60,
            choices: [item],
            harmonicContext: .isolated,
            replaysAllowed: nil,
            responseDeadline: nil
        )
    }

    func test_interval_drillType_includes_direction() {
        let s = spec(item: .interval(.majorThird), voicing: .ascending)
        XCTAssertEqual(s.drillType, "interval_major_3rd_ascending")
    }

    func test_interval_descending_drillType() {
        let s = spec(item: .interval(.perfectFifth), voicing: .descending)
        XCTAssertEqual(s.drillType, "interval_perfect_5th_descending")
    }

    func test_chord_drillType_omits_voicing() {
        let s = spec(item: .chord(.major), voicing: .harmonic)
        XCTAssertEqual(s.drillType, "chord_major")
    }

    func test_scale_drillType_omits_voicing() {
        let s = spec(item: .scale(.major), voicing: .ascending)
        XCTAssertEqual(s.drillType, "scale_major")
    }

    func test_degree_drillType_omits_voicing() {
        let s = spec(item: .degree(.sol), voicing: .ascending)
        XCTAssertEqual(s.drillType, "functional_degree_sol")
    }

    func test_correctChoiceIndex_finds_the_answer() {
        let item = ContentItem.interval(.majorThird)
        var s = spec(item: item, voicing: .ascending)
        s = DrillSpec(
            module: item.module, item: item, voicing: .ascending, rootMidi: 60,
            choices: [.interval(.perfectFifth), item, .interval(.octave)],
            harmonicContext: .isolated, replaysAllowed: nil, responseDeadline: nil
        )
        XCTAssertEqual(s.correctChoiceIndex, 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/DrillSpecTests 2>&1 | grep -E "error:|Executed [0-9]+ tests"
```
Expected: FAIL — `cannot find 'DrillSpec' in scope`

- [ ] **Step 3: Write minimal implementation**

Create `Tonestep/Core/Curriculum/DrillSpec.swift`:

```swift
import Foundation

/// One fully resolved question. Sampled from a stage's DifficultyParams by
/// CurriculumBuilder, then rendered by a drill view.
struct DrillSpec: Equatable {
    let module: TrainingModule
    let item: ContentItem
    let voicing: VoicingMode
    let rootMidi: UInt8
    let choices: [ContentItem]
    let harmonicContext: HarmonicContext
    let replaysAllowed: Int?
    let responseDeadline: TimeInterval?

    /// Join key for DrillResult and SRItem. Intervals carry direction, matching
    /// the legacy format; everything else does not.
    var drillType: String {
        switch item {
        case .interval:
            return "\(item.drillType)_\(voicing.legacySuffix)"
        case .chord, .scale, .degree:
            return item.drillType
        }
    }

    var correctChoiceIndex: Int? {
        choices.firstIndex(of: item)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/DrillSpecTests 2>&1 | grep -E "Executed [0-9]+ tests|TEST"
```
Expected: `Executed 6 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Tonestep/Core/Curriculum/DrillSpec.swift TonestepTests/DrillSpecTests.swift Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: add DrillSpec with legacy-compatible drillType"
```

---

### Task 5: Chapter, DifficultyEnvelope, Stage, PassCriteria

**Files:**
- Create: `Tonestep/Core/Curriculum/Chapter.swift`
- Test: `TonestepTests/ChapterTests.swift`

**Interfaces:**
- Consumes: `DifficultyParams` and its axis enums, `ContentItem`, `TrainingModule`.
- Produces: `DifficultyEnvelope.params(atStage:of:) -> DifficultyParams`; `Chapter`; `Stage` with `.id`; `PassCriteria.standard`.

The envelope is what keeps 102 stages down to ~150 lines of authored data. Every axis moves from a `start` value to an `end` value at a fixed fraction of the chapter, so difficulty is non-decreasing by construction.

- [ ] **Step 1: Write the failing test**

Create `TonestepTests/ChapterTests.swift`:

```swift
import XCTest
@testable import Tonestep

final class ChapterTests: XCTestCase {

    private func envelope() -> DifficultyEnvelope {
        DifficultyEnvelope(
            poolSteps: [
                [.interval(.perfectFifth), .interval(.octave)],
                [.interval(.perfectFifth), .interval(.octave), .interval(.perfectFourth)]
            ],
            answerSetStart: 2, answerSetEnd: 3,
            contextStart: .cadencePrimer, contextEnd: .droneRoot,
            voicingStart: [.ascending], voicingEnd: [.ascending, .descending],
            registerStart: .fixedMiddle, registerEnd: .twoOctaves,
            rootStart: .fixedC, rootEnd: .randomRoot,
            replaysAtEnd: 2, deadlineAtEnd: nil
        )
    }

    func test_first_stage_uses_start_values() {
        let p = envelope().params(atStage: 0, of: 8)
        XCTAssertEqual(p.harmonicContext, .cadencePrimer)
        XCTAssertEqual(p.registerSpan, .fixedMiddle)
        XCTAssertEqual(p.rootPolicy, .fixedC)
        XCTAssertEqual(p.contentPool.count, 2)
        XCTAssertNil(p.replaysAllowed)
    }

    func test_last_stage_uses_end_values() {
        let p = envelope().params(atStage: 7, of: 8)
        XCTAssertEqual(p.harmonicContext, .droneRoot)
        XCTAssertEqual(p.registerSpan, .twoOctaves)
        XCTAssertEqual(p.rootPolicy, .randomRoot)
        XCTAssertEqual(p.contentPool.count, 3)
        XCTAssertEqual(p.replaysAllowed, 2)
    }

    func test_answerSetSize_never_exceeds_pool() {
        var e = envelope()
        e = DifficultyEnvelope(
            poolSteps: [[.interval(.perfectFifth), .interval(.octave)]],
            answerSetStart: 6, answerSetEnd: 6,
            contextStart: .isolated, contextEnd: .isolated,
            voicingStart: [.ascending], voicingEnd: [.ascending],
            registerStart: .fixedMiddle, registerEnd: .fixedMiddle,
            rootStart: .fixedC, rootEnd: .fixedC,
            replaysAtEnd: nil, deadlineAtEnd: nil
        )
        let p = e.params(atStage: 0, of: 4)
        XCTAssertEqual(p.answerSetSize, 2)
    }

    func test_answerSetSize_is_at_least_two() {
        let e = DifficultyEnvelope(
            poolSteps: [[.interval(.perfectFifth), .interval(.octave)]],
            answerSetStart: 1, answerSetEnd: 1,
            contextStart: .isolated, contextEnd: .isolated,
            voicingStart: [.ascending], voicingEnd: [.ascending],
            registerStart: .fixedMiddle, registerEnd: .fixedMiddle,
            rootStart: .fixedC, rootEnd: .fixedC,
            replaysAtEnd: nil, deadlineAtEnd: nil
        )
        XCTAssertEqual(e.params(atStage: 0, of: 4).answerSetSize, 2)
    }

    func test_difficulty_is_non_decreasing_across_stages() {
        let e = envelope()
        let scores = (0..<8).map { e.params(atStage: $0, of: 8).difficultyScore }
        for i in 1..<scores.count {
            XCTAssertGreaterThanOrEqual(scores[i], scores[i - 1], "stage \(i) easier than \(i - 1)")
        }
    }

    func test_single_stage_chapter_uses_end_values() {
        let p = envelope().params(atStage: 0, of: 1)
        XCTAssertEqual(p.rootPolicy, .randomRoot)
    }

    func test_stage_id_format() {
        let s = Stage(chapterId: "finding_home", indexInChapter: 3,
                      params: envelope().params(atStage: 3, of: 8),
                      passCriteria: .standard)
        XCTAssertEqual(s.id, "finding_home-3")
    }

    func test_standard_pass_criteria() {
        XCTAssertEqual(PassCriteria.standard.minQuestions, 10)
        XCTAssertEqual(PassCriteria.standard.minAccuracy, 0.8, accuracy: 0.0001)
        XCTAssertEqual(PassCriteria.standard.starThresholds, [0.8, 0.9, 1.0])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/ChapterTests 2>&1 | grep -E "error:|Executed [0-9]+ tests"
```
Expected: FAIL — `cannot find 'DifficultyEnvelope' in scope`

- [ ] **Step 3: Write minimal implementation**

Create `Tonestep/Core/Curriculum/Chapter.swift`:

```swift
import Foundation

/// Compact description of how a chapter's difficulty moves from start to end.
/// Every axis is non-decreasing, so generated stages are monotonic by construction.
struct DifficultyEnvelope {
    /// Nested, growing pools. Stage i selects the step at its progress fraction.
    let poolSteps: [[ContentItem]]
    let answerSetStart: Int
    let answerSetEnd: Int
    let contextStart: HarmonicContext
    let contextEnd: HarmonicContext
    let voicingStart: Set<VoicingMode>
    let voicingEnd: Set<VoicingMode>
    let registerStart: RegisterSpan
    let registerEnd: RegisterSpan
    let rootStart: RootPolicy
    let rootEnd: RootPolicy
    /// Applied only in the last 15% of the chapter.
    let replaysAtEnd: Int?
    let deadlineAtEnd: TimeInterval?

    /// Fractions at which each discrete axis switches from start to end.
    private static let voicingSwitch = 0.4
    private static let contextSwitch = 0.5
    private static let registerSwitch = 0.6
    private static let rootSwitch = 0.7
    private static let pressureSwitch = 0.85

    func params(atStage index: Int, of total: Int) -> DifficultyParams {
        let t = total <= 1 ? 1.0 : Double(index) / Double(total - 1)

        let poolIndex = min(Int(t * Double(poolSteps.count)), poolSteps.count - 1)
        let pool = poolSteps[max(0, poolIndex)]

        let rawAnswerSet = answerSetStart
            + Int((Double(answerSetEnd - answerSetStart) * t).rounded())
        let answerSet = max(2, min(rawAnswerSet, pool.count))

        return DifficultyParams(
            contentPool: pool,
            answerSetSize: answerSet,
            harmonicContext: t >= Self.contextSwitch ? contextEnd : contextStart,
            voicings: t >= Self.voicingSwitch ? voicingEnd : voicingStart,
            registerSpan: t >= Self.registerSwitch ? registerEnd : registerStart,
            rootPolicy: t >= Self.rootSwitch ? rootEnd : rootStart,
            replaysAllowed: t >= Self.pressureSwitch ? replaysAtEnd : nil,
            responseDeadline: t >= Self.pressureSwitch ? deadlineAtEnd : nil,
            timbre: .primary
        )
    }
}

struct Chapter: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let modules: [TrainingModule]
    let stageCount: Int
    let envelope: DifficultyEnvelope
    let isProOnly: Bool
}

struct PassCriteria: Equatable {
    let minQuestions: Int
    let minAccuracy: Double
    /// Ascending accuracy thresholds for 1, 2 and 3 stars.
    let starThresholds: [Double]

    static let standard = PassCriteria(
        minQuestions: 10,
        minAccuracy: 0.8,
        starThresholds: [0.8, 0.9, 1.0]
    )
}

struct Stage: Identifiable, Equatable {
    let chapterId: String
    /// 0-based. Any user-facing number is computed at render time.
    let indexInChapter: Int
    let params: DifficultyParams
    let passCriteria: PassCriteria

    /// Persistent identity. Deliberately not a global integer: Phase 2 inserts
    /// chapters mid-arc, which would renumber every later stage and corrupt
    /// saved progress.
    var id: String { "\(chapterId)-\(indexInChapter)" }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/ChapterTests 2>&1 | grep -E "Executed [0-9]+ tests|TEST"
```
Expected: `Executed 8 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Tonestep/Core/Curriculum/Chapter.swift TonestepTests/ChapterTests.swift Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: add Chapter, DifficultyEnvelope, Stage and PassCriteria"
```

---

### Task 6: CurriculumBuilder chapter definitions and stage generation

**Files:**
- Create: `Tonestep/Core/Curriculum/CurriculumBuilder.swift`
- Test: `TonestepTests/CurriculumBuilderTests.swift`

**Interfaces:**
- Consumes: `Chapter`, `DifficultyEnvelope`, `Stage`, `PassCriteria`, `ContentItem`, `Entitlement`.
- Produces: `CurriculumBuilder.allChapters: [Chapter]`, `.chapters(for:) -> [Chapter]`, `.stages(for:) -> [Stage]`, `.stage(id:entitlement:) -> Stage?`.

The ten chapters run functional → intervallic → harmonic → modal → integrated. Opening on functional ear rather than intervals is deliberate: it is the skill that transfers to playing by ear, and "here are 13 intervals, memorise them" is where most competitors lose users.

- [ ] **Step 1: Write the failing test**

Create `TonestepTests/CurriculumBuilderTests.swift`:

```swift
import XCTest
@testable import Tonestep

final class CurriculumBuilderTests: XCTestCase {

    func test_free_curriculum_has_seven_chapters() {
        XCTAssertEqual(CurriculumBuilder.chapters(for: .free).count, 7)
    }

    func test_pro_curriculum_has_ten_chapters() {
        XCTAssertEqual(CurriculumBuilder.chapters(for: .pro).count, 10)
    }

    func test_free_curriculum_has_seventy_stages() {
        XCTAssertEqual(CurriculumBuilder.stages(for: .free).count, 70)
    }

    func test_pro_curriculum_has_one_hundred_two_stages() {
        XCTAssertEqual(CurriculumBuilder.stages(for: .pro).count, 102)
    }

    func test_no_free_chapter_is_pro_only() {
        XCTAssertTrue(CurriculumBuilder.chapters(for: .free).allSatisfy { !$0.isProOnly })
    }

    func test_first_chapter_is_functional_ear() {
        let first = CurriculumBuilder.chapters(for: .free)[0]
        XCTAssertEqual(first.id, "finding_home")
        XCTAssertEqual(first.modules, [.functionalEar])
    }

    func test_chapter_ids_are_unique() {
        let ids = CurriculumBuilder.allChapters.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_stage_ids_are_unique() {
        let ids = CurriculumBuilder.stages(for: .pro).map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func test_every_stage_has_a_non_empty_pool() {
        for stage in CurriculumBuilder.stages(for: .pro) {
            XCTAssertFalse(stage.params.contentPool.isEmpty, "empty pool at \(stage.id)")
        }
    }

    func test_every_stage_answer_set_fits_its_pool() {
        for stage in CurriculumBuilder.stages(for: .pro) {
            XCTAssertLessThanOrEqual(stage.params.answerSetSize, stage.params.contentPool.count,
                                     "answer set too large at \(stage.id)")
            XCTAssertGreaterThanOrEqual(stage.params.answerSetSize, 2, "answer set too small at \(stage.id)")
        }
    }

    func test_every_stage_has_at_least_one_voicing() {
        for stage in CurriculumBuilder.stages(for: .pro) {
            XCTAssertFalse(stage.params.voicings.isEmpty, "no voicings at \(stage.id)")
        }
    }

    func test_all_pools_use_only_anchor_modules() {
        let anchors: Set<TrainingModule> = [.intervalRecognition, .chordRecognition,
                                            .scaleRecognition, .functionalEar]
        for stage in CurriculumBuilder.stages(for: .pro) {
            for item in stage.params.contentPool {
                XCTAssertTrue(anchors.contains(item.module), "non-anchor module at \(stage.id)")
            }
        }
    }

    func test_difficulty_non_decreasing_within_every_chapter() {
        for chapter in CurriculumBuilder.allChapters {
            let scores = CurriculumBuilder.stages(for: .pro)
                .filter { $0.chapterId == chapter.id }
                .map(\.params.difficultyScore)
            for i in 1..<scores.count {
                XCTAssertGreaterThanOrEqual(scores[i], scores[i - 1],
                                            "\(chapter.id) stage \(i) easier than \(i - 1)")
            }
        }
    }

    func test_free_field_is_harder_than_finding_home() {
        let stages = CurriculumBuilder.stages(for: .pro)
        func mean(_ id: String) -> Double {
            let s = stages.filter { $0.chapterId == id }.map(\.params.difficultyScore)
            return s.reduce(0, +) / Double(s.count)
        }
        XCTAssertGreaterThan(mean("free_field"), mean("finding_home"))
    }

    func test_stage_lookup_by_id() {
        let stage = CurriculumBuilder.stage(id: "finding_home-0", entitlement: .free)
        XCTAssertNotNil(stage)
        XCTAssertEqual(stage?.chapterId, "finding_home")
        XCTAssertEqual(stage?.indexInChapter, 0)
    }

    func test_stage_lookup_of_pro_stage_fails_for_free_user() {
        XCTAssertNil(CurriculumBuilder.stage(id: "free_field-0", entitlement: .free))
        XCTAssertNotNil(CurriculumBuilder.stage(id: "free_field-0", entitlement: .pro))
    }

    func test_unknown_stage_id_returns_nil() {
        XCTAssertNil(CurriculumBuilder.stage(id: "nope-99", entitlement: .pro))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/CurriculumBuilderTests 2>&1 | grep -E "error:|Executed [0-9]+ tests"
```
Expected: FAIL — `cannot find 'CurriculumBuilder' in scope`

- [ ] **Step 3: Write minimal implementation**

Create `Tonestep/Core/Curriculum/CurriculumBuilder.swift`:

```swift
import Foundation

/// The authored curriculum. Ten chapters, 102 stages, running
/// functional -> intervallic -> harmonic -> modal -> integrated.
enum CurriculumBuilder {

    // MARK: - Pools

    private static let perfectPool1: [ContentItem] = [.interval(.perfectFifth), .interval(.octave)]
    private static let perfectPool2: [ContentItem] = [.interval(.perfectFifth), .interval(.octave), .interval(.perfectFourth)]

    private static let thirdsPool: [ContentItem] = [.interval(.minorThird), .interval(.majorThird)]
    private static let thirdsAndTriads: [ContentItem] = [
        .interval(.minorThird), .interval(.majorThird), .chord(.major), .chord(.minor)
    ]

    private static let triads2: [ContentItem] = [.chord(.major), .chord(.minor)]
    private static let triads3: [ContentItem] = [.chord(.major), .chord(.minor), .chord(.diminished)]
    private static let triads4: [ContentItem] = [.chord(.major), .chord(.minor), .chord(.diminished), .chord(.augmented)]

    private static let smallIntervals: [ContentItem] = [
        .interval(.minorSecond), .interval(.majorSecond), .interval(.minorThird), .interval(.majorThird)
    ]
    private static let midIntervals: [ContentItem] = smallIntervals + [
        .interval(.perfectFourth), .interval(.tritone), .interval(.perfectFifth)
    ]
    private static let allIntervals: [ContentItem] = midIntervals + [
        .interval(.minorSixth), .interval(.majorSixth),
        .interval(.minorSeventh), .interval(.majorSeventh), .interval(.octave)
    ]

    private static let degrees3: [ContentItem] = [.degree(.do_), .degree(.sol), .degree(.mi)]
    private static let degrees5: [ContentItem] = degrees3 + [.degree(.la), .degree(.re)]
    private static let degrees7: [ContentItem] = degrees5 + [.degree(.fa), .degree(.ti)]

    private static let scales2: [ContentItem] = [.scale(.major), .scale(.naturalMinor)]
    private static let scales4: [ContentItem] = scales2 + [.scale(.majorPentatonic), .scale(.minorPentatonic)]

    private static let sevenths3: [ContentItem] = [
        .chord(.dominantSeventh), .chord(.majorSeventh), .chord(.minorSeventh)
    ]
    private static let sevenths5: [ContentItem] = sevenths3 + [.chord(.suspendedFourth), .chord(.suspendedSecond)]
    private static let sevenths6: [ContentItem] = sevenths5 + [.chord(.addedNinth)]

    private static let modes3: [ContentItem] = [.scale(.dorian), .scale(.lydian), .scale(.mixolydian)]
    private static let modes4: [ContentItem] = modes3 + [.scale(.phrygian)]
    private static let modes7: [ContentItem] = modes4 + [
        .scale(.locrian), .scale(.harmonicMinor), .scale(.melodicMinor)
    ]

    private static let freeFieldSmall: [ContentItem] = midIntervals + triads4 + degrees7
    private static let freeFieldFull: [ContentItem] = allIntervals + triads4 + sevenths3 + degrees7 + scales4

    // MARK: - Chapters

    static let allChapters: [Chapter] = [
        Chapter(
            id: "finding_home", title: "Finding Home",
            subtitle: "Hear the tonic, then Sol, then Mi",
            modules: [.functionalEar], stageCount: 8,
            envelope: DifficultyEnvelope(
                poolSteps: [[.degree(.do_), .degree(.sol)], degrees3],
                answerSetStart: 2, answerSetEnd: 3,
                contextStart: .cadencePrimer, contextEnd: .cadencePrimer,
                voicingStart: [.ascending], voicingEnd: [.ascending],
                registerStart: .fixedMiddle, registerEnd: .fixedMiddle,
                rootStart: .fixedC, rootEnd: .fixedC,
                replaysAtEnd: nil, deadlineAtEnd: nil
            ),
            isProOnly: false
        ),
        Chapter(
            id: "perfect_intervals", title: "The Perfect Intervals",
            subtitle: "Fifths, octaves and fourths",
            modules: [.intervalRecognition], stageCount: 8,
            envelope: DifficultyEnvelope(
                poolSteps: [perfectPool1, perfectPool2],
                answerSetStart: 2, answerSetEnd: 3,
                contextStart: .cadencePrimer, contextEnd: .droneRoot,
                voicingStart: [.ascending], voicingEnd: [.ascending, .descending],
                registerStart: .fixedMiddle, registerEnd: .twoOctaves,
                rootStart: .fixedC, rootEnd: .fixedC,
                replaysAtEnd: nil, deadlineAtEnd: nil
            ),
            isProOnly: false
        ),
        Chapter(
            id: "major_vs_minor", title: "Major vs Minor",
            subtitle: "The third is what carries the mood",
            modules: [.intervalRecognition, .chordRecognition], stageCount: 10,
            envelope: DifficultyEnvelope(
                poolSteps: [thirdsPool, thirdsAndTriads],
                answerSetStart: 2, answerSetEnd: 4,
                contextStart: .cadencePrimer, contextEnd: .droneRoot,
                voicingStart: [.ascending], voicingEnd: [.ascending, .harmonic],
                registerStart: .fixedMiddle, registerEnd: .twoOctaves,
                rootStart: .fixedC, rootEnd: .randomRoot,
                replaysAtEnd: nil, deadlineAtEnd: nil
            ),
            isProOnly: false
        ),
        Chapter(
            id: "triad_family", title: "The Triad Family",
            subtitle: "Add diminished and augmented",
            modules: [.chordRecognition], stageCount: 10,
            envelope: DifficultyEnvelope(
                poolSteps: [triads2, triads3, triads4],
                answerSetStart: 2, answerSetEnd: 4,
                contextStart: .cadencePrimer, contextEnd: .droneRoot,
                voicingStart: [.harmonic], voicingEnd: [.harmonic, .ascending],
                registerStart: .fixedMiddle, registerEnd: .twoOctaves,
                rootStart: .fixedC, rootEnd: .randomRoot,
                replaysAtEnd: nil, deadlineAtEnd: nil
            ),
            isProOnly: false
        ),
        Chapter(
            id: "steps_and_leaps", title: "Steps and Leaps",
            subtitle: "Every interval in the octave",
            modules: [.intervalRecognition], stageCount: 12,
            envelope: DifficultyEnvelope(
                poolSteps: [smallIntervals, midIntervals, allIntervals],
                answerSetStart: 4, answerSetEnd: 6,
                contextStart: .droneRoot, contextEnd: .isolated,
                voicingStart: [.ascending, .descending],
                voicingEnd: [.ascending, .descending, .harmonic],
                registerStart: .twoOctaves, registerEnd: .threeOctaves,
                rootStart: .fixedC, rootEnd: .randomRoot,
                replaysAtEnd: 2, deadlineAtEnd: nil
            ),
            isProOnly: false
        ),
        Chapter(
            id: "hearing_function", title: "Hearing Function, Not Distance",
            subtitle: "All seven degrees, losing the drone",
            modules: [.functionalEar], stageCount: 12,
            envelope: DifficultyEnvelope(
                poolSteps: [degrees3, degrees5, degrees7],
                answerSetStart: 3, answerSetEnd: 7,
                contextStart: .droneRoot, contextEnd: .isolated,
                voicingStart: [.ascending], voicingEnd: [.ascending],
                registerStart: .fixedMiddle, registerEnd: .twoOctaves,
                rootStart: .fixedC, rootEnd: .randomRoot,
                replaysAtEnd: 2, deadlineAtEnd: nil
            ),
            isProOnly: false
        ),
        Chapter(
            id: "scales_and_modes", title: "Scales and Modes",
            subtitle: "Major, minor and the pentatonics",
            modules: [.scaleRecognition], stageCount: 10,
            envelope: DifficultyEnvelope(
                poolSteps: [scales2, scales4],
                answerSetStart: 2, answerSetEnd: 4,
                contextStart: .cadencePrimer, contextEnd: .droneRoot,
                voicingStart: [.ascending], voicingEnd: [.ascending, .descending],
                registerStart: .fixedMiddle, registerEnd: .twoOctaves,
                rootStart: .fixedC, rootEnd: .randomRoot,
                replaysAtEnd: nil, deadlineAtEnd: nil
            ),
            isProOnly: false
        ),
        Chapter(
            id: "sevenths_and_colour", title: "Sevenths and Colour",
            subtitle: "Four-note chords and suspensions",
            modules: [.chordRecognition], stageCount: 10,
            envelope: DifficultyEnvelope(
                poolSteps: [sevenths3, sevenths5, sevenths6],
                answerSetStart: 3, answerSetEnd: 6,
                contextStart: .droneRoot, contextEnd: .isolated,
                voicingStart: [.harmonic], voicingEnd: [.harmonic, .ascending],
                registerStart: .twoOctaves, registerEnd: .threeOctaves,
                rootStart: .fixedC, rootEnd: .randomRoot,
                replaysAtEnd: 2, deadlineAtEnd: nil
            ),
            isProOnly: true
        ),
        Chapter(
            id: "modal_colours", title: "Modal Colours",
            subtitle: "Dorian through Locrian",
            modules: [.scaleRecognition], stageCount: 10,
            envelope: DifficultyEnvelope(
                poolSteps: [modes3, modes4, modes7],
                answerSetStart: 3, answerSetEnd: 6,
                contextStart: .droneRoot, contextEnd: .isolated,
                voicingStart: [.ascending], voicingEnd: [.ascending, .descending],
                registerStart: .twoOctaves, registerEnd: .threeOctaves,
                rootStart: .fixedC, rootEnd: .randomRoot,
                replaysAtEnd: 2, deadlineAtEnd: nil
            ),
            isProOnly: true
        ),
        Chapter(
            id: "free_field", title: "Free Field",
            subtitle: "No context, random roots, against the clock",
            modules: [.intervalRecognition, .chordRecognition, .scaleRecognition, .functionalEar],
            stageCount: 12,
            envelope: DifficultyEnvelope(
                poolSteps: [freeFieldSmall, freeFieldFull],
                answerSetStart: 4, answerSetEnd: 8,
                contextStart: .isolated, contextEnd: .isolated,
                voicingStart: [.ascending, .descending],
                voicingEnd: [.ascending, .descending, .harmonic],
                registerStart: .twoOctaves, registerEnd: .threeOctaves,
                rootStart: .randomRoot, rootEnd: .randomRoot,
                replaysAtEnd: 0, deadlineAtEnd: 8
            ),
            isProOnly: true
        )
    ]

    // MARK: - Access

    static func chapters(for entitlement: Entitlement) -> [Chapter] {
        switch entitlement {
        case .pro:  return allChapters
        case .free: return allChapters.filter { !$0.isProOnly }
        }
    }

    static func stages(for entitlement: Entitlement) -> [Stage] {
        chapters(for: entitlement).flatMap { chapter in
            (0..<chapter.stageCount).map { index in
                Stage(
                    chapterId: chapter.id,
                    indexInChapter: index,
                    params: chapter.envelope.params(atStage: index, of: chapter.stageCount),
                    passCriteria: .standard
                )
            }
        }
    }

    static func stage(id: String, entitlement: Entitlement) -> Stage? {
        stages(for: entitlement).first { $0.id == id }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/CurriculumBuilderTests 2>&1 | grep -E "Executed [0-9]+ tests|TEST"
```
Expected: `Executed 17 tests, with 0 failures`

If `test_difficulty_non_decreasing_within_every_chapter` fails, the named chapter has an envelope whose `end` value is easier than its `start` on some axis. Fix the chapter data, not the test.

- [ ] **Step 5: Commit**

```bash
git add Tonestep/Core/Curriculum/CurriculumBuilder.swift TonestepTests/CurriculumBuilderTests.swift Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: add 10-chapter curriculum generating 102 graded stages"
```

---

### Task 7: Deterministic drill sampling

**Files:**
- Modify: `Tonestep/Core/Curriculum/CurriculumBuilder.swift`
- Create: `Tonestep/Core/Curriculum/SeededGenerator.swift`
- Test: `TonestepTests/DrillSamplingTests.swift`

**Interfaces:**
- Consumes: `Stage`, `DifficultyParams`, `DrillSpec`.
- Produces: `SeededGenerator(seed:)`; `CurriculumBuilder.drillSpecs(for:count:) -> [DrillSpec]`.

Determinism matters so a given stage always presents the same drills. `String.hashValue` is randomly seeded per process and must not be used — hence an explicit FNV-1a hash. `Set` iteration order is likewise unstable, so voicings are sorted before sampling.

- [ ] **Step 1: Write the failing test**

Create `TonestepTests/DrillSamplingTests.swift`:

```swift
import XCTest
@testable import Tonestep

final class DrillSamplingTests: XCTestCase {

    private var stage: Stage {
        CurriculumBuilder.stage(id: "steps_and_leaps-5", entitlement: .pro)!
    }

    func test_sampling_is_deterministic() {
        let a = CurriculumBuilder.drillSpecs(for: stage, count: 10)
        let b = CurriculumBuilder.drillSpecs(for: stage, count: 10)
        XCTAssertEqual(a, b)
    }

    func test_different_stages_produce_different_drills() {
        let a = CurriculumBuilder.drillSpecs(
            for: CurriculumBuilder.stage(id: "steps_and_leaps-5", entitlement: .pro)!, count: 10)
        let b = CurriculumBuilder.drillSpecs(
            for: CurriculumBuilder.stage(id: "steps_and_leaps-6", entitlement: .pro)!, count: 10)
        XCTAssertNotEqual(a, b)
    }

    func test_requested_count_is_returned() {
        XCTAssertEqual(CurriculumBuilder.drillSpecs(for: stage, count: 10).count, 10)
    }

    func test_zero_count_returns_empty() {
        XCTAssertTrue(CurriculumBuilder.drillSpecs(for: stage, count: 0).isEmpty)
    }

    func test_every_spec_answer_is_among_its_choices() {
        for spec in CurriculumBuilder.drillSpecs(for: stage, count: 30) {
            XCTAssertNotNil(spec.correctChoiceIndex, "answer missing from choices")
        }
    }

    func test_choice_count_matches_answer_set_size() {
        let s = stage
        for spec in CurriculumBuilder.drillSpecs(for: s, count: 30) {
            XCTAssertEqual(spec.choices.count, s.params.answerSetSize)
        }
    }

    func test_choices_have_no_duplicates() {
        for spec in CurriculumBuilder.drillSpecs(for: stage, count: 30) {
            XCTAssertEqual(Set(spec.choices).count, spec.choices.count)
        }
    }

    func test_item_and_voicing_come_from_the_stage_params() {
        let s = stage
        for spec in CurriculumBuilder.drillSpecs(for: s, count: 30) {
            XCTAssertTrue(s.params.contentPool.contains(spec.item))
            XCTAssertTrue(s.params.voicings.contains(spec.voicing))
        }
    }

    func test_fixed_root_policy_always_uses_middle_c() {
        let s = CurriculumBuilder.stage(id: "finding_home-0", entitlement: .free)!
        XCTAssertEqual(s.params.rootPolicy, .fixedC)
        for spec in CurriculumBuilder.drillSpecs(for: s, count: 20) {
            XCTAssertEqual(spec.rootMidi, 60)
        }
    }

    func test_root_stays_within_register_span() {
        let s = stage
        for spec in CurriculumBuilder.drillSpecs(for: s, count: 30) {
            XCTAssertTrue(s.params.registerSpan.midiRange.contains(spec.rootMidi))
        }
    }

    func test_every_stage_in_curriculum_yields_valid_drills() {
        for s in CurriculumBuilder.stages(for: .pro) {
            let specs = CurriculumBuilder.drillSpecs(for: s, count: 10)
            XCTAssertEqual(specs.count, 10, "no drills at \(s.id)")
            for spec in specs {
                XCTAssertNotNil(spec.correctChoiceIndex, "invalid drill at \(s.id)")
            }
        }
    }

    func test_every_stage_yields_valid_drills_for_free_users() {
        for s in CurriculumBuilder.stages(for: .free) {
            XCTAssertEqual(CurriculumBuilder.drillSpecs(for: s, count: 10).count, 10, "no drills at \(s.id)")
        }
    }

    func test_seeded_generator_is_reproducible() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        XCTAssertEqual(a.next(), b.next())
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/DrillSamplingTests 2>&1 | grep -E "error:|Executed [0-9]+ tests"
```
Expected: FAIL — `cannot find 'SeededGenerator' in scope`

- [ ] **Step 3a: Create the generator**

Create `Tonestep/Core/Curriculum/SeededGenerator.swift`:

```swift
import Foundation

/// xorshift64. Reproducible across runs and platforms, unlike SystemRandomNumberGenerator.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // xorshift breaks down at zero.
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// FNV-1a. String.hashValue is randomly seeded per process, so it cannot be
    /// used anywhere determinism is required.
    static func seed(from string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
```

- [ ] **Step 3b: Add sampling to CurriculumBuilder**

Append inside `enum CurriculumBuilder`, after `stage(id:entitlement:)`:

```swift
    /// Samples `count` resolved drills from a stage. Deterministic: the same
    /// stage always yields the same drills, in the same order.
    static func drillSpecs(for stage: Stage, count: Int) -> [DrillSpec] {
        guard count > 0 else { return [] }
        let params = stage.params
        guard !params.contentPool.isEmpty else { return [] }

        // Sorted, because Set iteration order is not stable across runs.
        let voicings = params.voicings.sorted()
        guard !voicings.isEmpty else { return [] }

        var rng = SeededGenerator(seed: SeededGenerator.seed(from: stage.id))
        var specs: [DrillSpec] = []

        for _ in 0..<count {
            let item = params.contentPool.randomElement(using: &rng)!
            let voicing = voicings.randomElement(using: &rng)!

            let root: UInt8
            switch params.rootPolicy {
            case .fixedC:
                root = 60
            case .randomRoot:
                root = UInt8.random(in: params.registerSpan.midiRange, using: &rng)
            }

            let distractors = params.contentPool
                .filter { $0 != item }
                .shuffled(using: &rng)
                .prefix(max(0, params.answerSetSize - 1))
            let choices = ([item] + distractors).shuffled(using: &rng)

            specs.append(DrillSpec(
                module: item.module,
                item: item,
                voicing: voicing,
                rootMidi: root,
                choices: choices,
                harmonicContext: params.harmonicContext,
                replaysAllowed: params.replaysAllowed,
                responseDeadline: params.responseDeadline
            ))
        }
        return specs
    }
```

Note: `fixedC` uses MIDI 60 regardless of `registerSpan`, and `RegisterSpan.fixedMiddle.midiRange` is `60...60`, so `test_root_stays_within_register_span` holds in both policies.

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/DrillSamplingTests 2>&1 | grep -E "Executed [0-9]+ tests|TEST"
```
Expected: `Executed 13 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Tonestep/Core/Curriculum/SeededGenerator.swift Tonestep/Core/Curriculum/CurriculumBuilder.swift TonestepTests/DrillSamplingTests.swift Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: add deterministic drill sampling from stage params"
```

---

### Task 8: StageEvaluator

**Files:**
- Create: `Tonestep/Core/Curriculum/StageEvaluator.swift`
- Test: `TonestepTests/StageEvaluatorTests.swift`

**Interfaces:**
- Consumes: `DrillResult` (existing), `PassCriteria`.
- Produces: `StageOutcome(passed:accuracy:stars:)`; `StageEvaluator.evaluate(results:criteria:) -> StageOutcome`.

- [ ] **Step 1: Write the failing test**

Create `TonestepTests/StageEvaluatorTests.swift`:

```swift
import XCTest
@testable import Tonestep

final class StageEvaluatorTests: XCTestCase {

    private func results(correct: Int, wrong: Int) -> [DrillResult] {
        let ok = (0..<correct).map { _ in
            DrillResult(module: .intervalRecognition, drillType: "t", wasCorrect: true, responseTime: 1)
        }
        let bad = (0..<wrong).map { _ in
            DrillResult(module: .intervalRecognition, drillType: "t", wasCorrect: false, responseTime: 1)
        }
        return ok + bad
    }

    func test_exactly_at_threshold_passes() {
        let outcome = StageEvaluator.evaluate(results: results(correct: 8, wrong: 2), criteria: .standard)
        XCTAssertTrue(outcome.passed)
        XCTAssertEqual(outcome.accuracy, 0.8, accuracy: 0.0001)
    }

    func test_below_threshold_fails() {
        let outcome = StageEvaluator.evaluate(results: results(correct: 7, wrong: 3), criteria: .standard)
        XCTAssertFalse(outcome.passed)
    }

    func test_too_few_questions_fails_even_at_full_accuracy() {
        let outcome = StageEvaluator.evaluate(results: results(correct: 9, wrong: 0), criteria: .standard)
        XCTAssertFalse(outcome.passed)
        XCTAssertEqual(outcome.stars, 0)
    }

    func test_empty_results_fail_without_crashing() {
        let outcome = StageEvaluator.evaluate(results: [], criteria: .standard)
        XCTAssertFalse(outcome.passed)
        XCTAssertEqual(outcome.accuracy, 0, accuracy: 0.0001)
        XCTAssertEqual(outcome.stars, 0)
    }

    func test_perfect_score_earns_three_stars() {
        XCTAssertEqual(StageEvaluator.evaluate(results: results(correct: 10, wrong: 0), criteria: .standard).stars, 3)
    }

    func test_ninety_percent_earns_two_stars() {
        XCTAssertEqual(StageEvaluator.evaluate(results: results(correct: 9, wrong: 1), criteria: .standard).stars, 2)
    }

    func test_eighty_percent_earns_one_star() {
        XCTAssertEqual(StageEvaluator.evaluate(results: results(correct: 8, wrong: 2), criteria: .standard).stars, 1)
    }

    func test_failing_run_earns_no_stars() {
        XCTAssertEqual(StageEvaluator.evaluate(results: results(correct: 5, wrong: 5), criteria: .standard).stars, 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/StageEvaluatorTests 2>&1 | grep -E "error:|Executed [0-9]+ tests"
```
Expected: FAIL — `cannot find 'StageEvaluator' in scope`

- [ ] **Step 3: Write minimal implementation**

Create `Tonestep/Core/Curriculum/StageEvaluator.swift`:

```swift
import Foundation

struct StageOutcome: Equatable {
    let passed: Bool
    let accuracy: Double
    let stars: Int
}

enum StageEvaluator {
    static func evaluate(results: [DrillResult], criteria: PassCriteria) -> StageOutcome {
        let total = results.count
        guard total > 0 else {
            return StageOutcome(passed: false, accuracy: 0, stars: 0)
        }

        let accuracy = Double(results.filter(\.wasCorrect).count) / Double(total)

        guard total >= criteria.minQuestions else {
            return StageOutcome(passed: false, accuracy: accuracy, stars: 0)
        }

        let passed = accuracy >= criteria.minAccuracy
        let stars = passed ? criteria.starThresholds.filter { accuracy >= $0 }.count : 0
        return StageOutcome(passed: passed, accuracy: accuracy, stars: stars)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/StageEvaluatorTests 2>&1 | grep -E "Executed [0-9]+ tests|TEST"
```
Expected: `Executed 8 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Tonestep/Core/Curriculum/StageEvaluator.swift TonestepTests/StageEvaluatorTests.swift Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: add StageEvaluator for pass and star scoring"
```

---

### Task 9: JourneyProgress and StageRecord persistence

**Files:**
- Create: `Tonestep/Core/Curriculum/JourneyProgress.swift`
- Modify: `Tonestep/App/TonestepApp.swift:41`
- Test: `TonestepTests/JourneyProgressTests.swift`

**Interfaces:**
- Consumes: SwiftData.
- Produces: `JourneyProgress(currentChapterId:currentIndexInChapter:)` with `.currentStageId`, `.advance(to:)`; `StageRecord(stageId:)` with `.record(outcome:)`.

- [ ] **Step 1: Write the failing test**

Create `TonestepTests/JourneyProgressTests.swift`:

```swift
import XCTest
@testable import Tonestep

final class JourneyProgressTests: XCTestCase {

    func test_currentStageId_matches_stage_id_format() {
        let p = JourneyProgress(currentChapterId: "finding_home", currentIndexInChapter: 3)
        XCTAssertEqual(p.currentStageId, "finding_home-3")
    }

    func test_default_starts_at_index_zero() {
        XCTAssertEqual(JourneyProgress(currentChapterId: "finding_home").currentIndexInChapter, 0)
    }

    func test_advance_updates_position() {
        let p = JourneyProgress(currentChapterId: "finding_home")
        let next = CurriculumBuilder.stage(id: "perfect_intervals-0", entitlement: .free)!
        p.advance(to: next)
        XCTAssertEqual(p.currentChapterId, "perfect_intervals")
        XCTAssertEqual(p.currentIndexInChapter, 0)
        XCTAssertEqual(p.currentStageId, "perfect_intervals-0")
    }

    func test_record_stores_outcome() {
        let r = StageRecord(stageId: "finding_home-0")
        r.record(outcome: StageOutcome(passed: true, accuracy: 0.9, stars: 2))
        XCTAssertEqual(r.bestAccuracy, 0.9, accuracy: 0.0001)
        XCTAssertEqual(r.stars, 2)
        XCTAssertNotNil(r.passedAt)
    }

    func test_record_keeps_the_best_result() {
        let r = StageRecord(stageId: "finding_home-0")
        r.record(outcome: StageOutcome(passed: true, accuracy: 1.0, stars: 3))
        r.record(outcome: StageOutcome(passed: true, accuracy: 0.8, stars: 1))
        XCTAssertEqual(r.bestAccuracy, 1.0, accuracy: 0.0001)
        XCTAssertEqual(r.stars, 3)
    }

    func test_failing_run_does_not_set_passedAt() {
        let r = StageRecord(stageId: "finding_home-0")
        r.record(outcome: StageOutcome(passed: false, accuracy: 0.5, stars: 0))
        XCTAssertNil(r.passedAt)
        XCTAssertEqual(r.bestAccuracy, 0.5, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/JourneyProgressTests 2>&1 | grep -E "error:|Executed [0-9]+ tests"
```
Expected: FAIL — `cannot find 'JourneyProgress' in scope`

- [ ] **Step 3a: Create the models**

Create `Tonestep/Core/Curriculum/JourneyProgress.swift`:

```swift
import Foundation
import SwiftData

/// Where the user currently is in the curriculum.
/// Stored as chapter id plus index, never a global stage number, so inserting a
/// chapter in Phase 2 cannot corrupt saved progress.
@Model
final class JourneyProgress {
    var currentChapterId: String
    var currentIndexInChapter: Int
    var lastUpdated: Date

    init(currentChapterId: String, currentIndexInChapter: Int = 0) {
        self.currentChapterId = currentChapterId
        self.currentIndexInChapter = currentIndexInChapter
        self.lastUpdated = Date()
    }

    var currentStageId: String { "\(currentChapterId)-\(currentIndexInChapter)" }

    func advance(to stage: Stage) {
        currentChapterId = stage.chapterId
        currentIndexInChapter = stage.indexInChapter
        lastUpdated = Date()
    }
}

/// Best result achieved on a single stage.
@Model
final class StageRecord {
    var stageId: String
    var bestAccuracy: Double
    var stars: Int
    var passedAt: Date?

    init(stageId: String) {
        self.stageId = stageId
        self.bestAccuracy = 0
        self.stars = 0
        self.passedAt = nil
    }

    func record(outcome: StageOutcome) {
        if outcome.accuracy > bestAccuracy {
            bestAccuracy = outcome.accuracy
            stars = outcome.stars
        }
        if outcome.passed && passedAt == nil {
            passedAt = Date()
        }
    }
}
```

- [ ] **Step 3b: Register the models in the container**

In `Tonestep/App/TonestepApp.swift`, replace line 41:

```swift
                .modelContainer(for: [DrillResult.self, DailySessionRecord.self, SRItem.self])
```

with:

```swift
                .modelContainer(for: [
                    DrillResult.self, DailySessionRecord.self, SRItem.self,
                    JourneyProgress.self, StageRecord.self
                ])
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/JourneyProgressTests 2>&1 | grep -E "Executed [0-9]+ tests|TEST"
```
Expected: `Executed 6 tests, with 0 failures`

- [ ] **Step 5: Commit**

```bash
git add Tonestep/Core/Curriculum/JourneyProgress.swift Tonestep/App/TonestepApp.swift TonestepTests/JourneyProgressTests.swift Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: add JourneyProgress and StageRecord persistence"
```

---

### Task 10: JourneySeeder for existing users

**Files:**
- Create: `Tonestep/Core/Curriculum/JourneySeeder.swift`
- Test: `TonestepTests/JourneySeederTests.swift`

**Interfaces:**
- Consumes: `DrillResult`, `CurriculumBuilder`, `Entitlement`, `Stage`.
- Produces: `JourneySeeder.inferStartingStage(from:entitlement:) -> Stage`.

Existing users have drill history. Dropping them at stage 1 would read as a wipe of their progress. A chapter is skipped when the user already has at least 10 results in that chapter's modules at 80% or better.

- [ ] **Step 1: Write the failing test**

Create `TonestepTests/JourneySeederTests.swift`:

```swift
import XCTest
@testable import Tonestep

final class JourneySeederTests: XCTestCase {

    private func results(module: TrainingModule, correct: Int, wrong: Int) -> [DrillResult] {
        let ok = (0..<correct).map { _ in
            DrillResult(module: module, drillType: "t", wasCorrect: true, responseTime: 1)
        }
        let bad = (0..<wrong).map { _ in
            DrillResult(module: module, drillType: "t", wasCorrect: false, responseTime: 1)
        }
        return ok + bad
    }

    func test_no_history_starts_at_the_first_stage() {
        let stage = JourneySeeder.inferStartingStage(from: [], entitlement: .free)
        XCTAssertEqual(stage.id, "finding_home-0")
    }

    func test_strong_functional_history_skips_the_first_chapter() {
        let stage = JourneySeeder.inferStartingStage(
            from: results(module: .functionalEar, correct: 18, wrong: 2), entitlement: .free)
        XCTAssertEqual(stage.chapterId, "perfect_intervals")
        XCTAssertEqual(stage.indexInChapter, 0)
    }

    func test_weak_history_does_not_skip() {
        let stage = JourneySeeder.inferStartingStage(
            from: results(module: .functionalEar, correct: 5, wrong: 15), entitlement: .free)
        XCTAssertEqual(stage.chapterId, "finding_home")
    }

    func test_insufficient_volume_does_not_skip() {
        let stage = JourneySeeder.inferStartingStage(
            from: results(module: .functionalEar, correct: 5, wrong: 0), entitlement: .free)
        XCTAssertEqual(stage.chapterId, "finding_home")
    }

    func test_strong_history_in_two_modules_skips_two_chapters() {
        let history = results(module: .functionalEar, correct: 18, wrong: 2)
            + results(module: .intervalRecognition, correct: 18, wrong: 2)
        let stage = JourneySeeder.inferStartingStage(from: history, entitlement: .free)
        XCTAssertEqual(stage.chapterId, "major_vs_minor")
    }

    func test_free_user_never_lands_on_a_pro_stage() {
        let history = TrainingModule.allCases.flatMap { results(module: $0, correct: 50, wrong: 0) }
        let stage = JourneySeeder.inferStartingStage(from: history, entitlement: .free)
        let freeIds = Set(CurriculumBuilder.stages(for: .free).map(\.id))
        XCTAssertTrue(freeIds.contains(stage.id))
    }

    func test_mastery_of_everything_lands_on_the_last_stage() {
        let history = TrainingModule.allCases.flatMap { results(module: $0, correct: 50, wrong: 0) }
        let stage = JourneySeeder.inferStartingStage(from: history, entitlement: .pro)
        XCTAssertEqual(stage.id, CurriculumBuilder.stages(for: .pro).last?.id)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/JourneySeederTests 2>&1 | grep -E "error:|Executed [0-9]+ tests"
```
Expected: FAIL — `cannot find 'JourneySeeder' in scope`

- [ ] **Step 3: Write minimal implementation**

Create `Tonestep/Core/Curriculum/JourneySeeder.swift`:

```swift
import Foundation

/// Places an existing user at a sensible point in the curriculum, so shipping
/// the journey does not look like their progress was wiped.
enum JourneySeeder {

    /// A chapter counts as already mastered at this volume and accuracy.
    private static let minResults = 10
    private static let minAccuracy = 0.8

    static func inferStartingStage(from results: [DrillResult], entitlement: Entitlement) -> Stage {
        let chapters = CurriculumBuilder.chapters(for: entitlement)
        let stages = CurriculumBuilder.stages(for: entitlement)

        // stages(for:) is never empty: chapters(for: .free) always yields 7 chapters.
        guard let firstStage = stages.first, let lastStage = stages.last else {
            fatalError("Curriculum is empty — CurriculumBuilder.allChapters must not be empty")
        }
        guard !results.isEmpty else { return firstStage }

        for chapter in chapters {
            // Every module in the chapter must be mastered independently. Pooling
            // them would let strong interval history skip a chapter that also
            // covers chords the user has never attempted.
            let mastered = chapter.modules.allSatisfy { module in
                let relevant = results.filter { $0.module == module }
                guard relevant.count >= minResults else { return false }
                let accuracy = Double(relevant.filter(\.wasCorrect).count) / Double(relevant.count)
                return accuracy >= minAccuracy
            }
            if mastered { continue }

            return stages.first { $0.chapterId == chapter.id } ?? firstStage
        }

        return lastStage
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
xcodegen generate && xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' -only-testing:TonestepTests/JourneySeederTests 2>&1 | grep -E "Executed [0-9]+ tests|TEST"
```
Expected: `Executed 7 tests, with 0 failures`

- [ ] **Step 5: Run the whole suite and commit**

```bash
xcodebuild test -scheme Tonestep -destination 'platform=iOS Simulator,id=907A43A4-894B-4875-A20B-660CFCB02AD0' 2>&1 | grep -E "Executed [0-9]+ tests|TEST (SUCCEEDED|FAILED)"
```
Expected: `Executed 100 tests, with 0 failures` and `** TEST SUCCEEDED **`
(11 pre-existing + 89 new. If the count differs, confirm no test file was missed by xcodegen.)

```bash
git add Tonestep/Core/Curriculum/JourneySeeder.swift TonestepTests/JourneySeederTests.swift Tonestep.xcodeproj/project.pbxproj
git commit -m "feat: seed journey position from existing drill history"
```

---

## Definition of done

- `xcodebuild test -scheme Tonestep` passes with 0 failures.
- `CurriculumBuilder.stages(for: .free).count == 70`, `.pro == 102`.
- Every stage in both entitlements yields 10 valid drills whose answer is among the choices.
- Difficulty is non-decreasing within every chapter.
- Sampling is reproducible across processes.
- No UI file has been modified except `TonestepApp.swift` for model registration.

## Follow-on plans

1. **Curriculum integration** — refactor the four anchor drill views to render a `DrillSpec`, delete `DailySessionBuilder.randomDrillType`, build `JourneyView`, surface stage state in `TodayView`. Requires reading `ChordDrillView`, `ScaleDrillView` and `FunctionalEarDrillView` first; only `IntervalDrillView` has been audited so far.
2. **Instrument audio** — bundle a real soundfont, honour the onboarding instrument choice, activate the `timbre` axis.
