# Curriculum Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the 102-stage curriculum reachable and playable, and fix the Daily Session so it works for every module.

**Architecture:** The four drill views gain an optional `DrillSpec`. When supplied they render that exact drill; when nil they keep today's random behaviour, so every existing call site is unaffected. `DrillDispatchView` gains a spec-driven overload, which `StageSessionView` uses to run a stage end to end.

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData, XCTest, xcodegen.

> **Deviation from the writing-plans skill, stated plainly:** this plan does not inline every line of implementation code, because it is being executed immediately in the same session by the author. It fixes file paths, interfaces and test strategy — enough for review and for the work to be checked — but a cold reader would need to open the files.

## Global Constraints

- Everything is additive. No existing call site of a `*DrillView` changes behaviour.
- `drillType` strings stay exactly as they are — SR history must keep matching.
- Curriculum position is **Stage**; `TonestepLevel` keeps **Level** for XP.
- Entitlement comes from `StoreManager.isPro`, converted at the call site.
- Run `xcodegen generate` after adding files.
- Scheme is `Tonestep`. Simulator `907A43A4-894B-4875-A20B-660CFCB02AD0`.
- Baseline before starting: 144 tests passing.

## Current state this fixes

- `CurriculumBuilder` is referenced only inside `Core/Curriculum/` — no view reaches it. 102 stages are unreachable.
- `JourneyProgress` appears in zero views.
- `SREngine.swift:119` returns hardcoded `"interval_major_third_ascending"` for 11 of 15 modules.

---

### Task 1: Drill views accept a DrillSpec

**Files:** `Tonestep/Modules/Train/{IntervalModuleView,ChordDrillView,ScaleDrillView,FunctionalEarDrillView}.swift`, `Tonestep/Modules/Today/DailySessionView.swift`

Each `*DrillView` gains `var spec: DrillSpec? = nil`. In `newDrill()`, when `spec` is non-nil, take the target item, `rootMidi` and `choices` from it instead of randomising. Default `nil` keeps current behaviour.

`DrillDispatchView` gains a second initialiser taking `DrillSpec`, routing on `spec.module` rather than string prefixes.

**Interfaces produced:** `IntervalDrillView(drillType:spec:onComplete:)` and siblings; `DrillDispatchView(spec:onComplete:)`.

- [ ] Add `spec` to all four drill views and honour it in `newDrill()`
- [ ] Add the `DrillDispatchView` spec overload
- [ ] Build; confirm 144 tests still pass (pure addition, no behaviour change)
- [ ] Commit

---

### Task 2: StageSessionView

**Files:** Create `Tonestep/Modules/Journey/StageSessionView.swift`

Runs one stage: pulls `CurriculumBuilder.drillSpecs(for:count:)` (count = `stage.passCriteria.minQuestions`), presents each through `DrillDispatchView(spec:)`, writes a `DrillResult` per answer, then evaluates with `StageEvaluator`.

On completion: upsert `StageRecord` for `stage.id`, and if passed, advance `JourneyProgress` to the next stage in `CurriculumBuilder.stages(for:)`.

**Interfaces produced:** `StageSessionView(stage:entitlement:)`.

- [ ] Create the view and its persistence
- [ ] Build and verify a stage plays end to end in the Simulator
- [ ] Commit

---

### Task 3: JourneyView

**Files:** Create `Tonestep/Modules/Journey/JourneyView.swift`

Lists chapters with their stages. Each stage shows locked / current / passed-with-stars, driven by `JourneyProgress` and `StageRecord` queries. Tapping the current or any passed stage opens `StageSessionView`.

Seeds `JourneyProgress` on first appearance using `JourneySeeder.inferStartingStage(from:entitlement:)` over existing `DrillResult` history, so current users are not reset to stage 1.

**Interfaces produced:** `JourneyView()`.

- [ ] Create the view, seeding, and stage-state rendering
- [ ] Build and verify in the Simulator
- [ ] Commit

---

### Task 4: Surface the journey in Today

**Files:** `Tonestep/Modules/Today/TodayView.swift`

Add a Journey card above the Daily Session card showing the current chapter title and stage number, linking to `JourneyView`.

- [ ] Add the card and navigation
- [ ] Verify in the Simulator
- [ ] Commit

---

### Task 5: Fix the Daily Session for every module

**Files:** `Tonestep/Core/SpacedRepetition/SREngine.swift`, `Tonestep/Modules/Today/DailySessionView.swift`, `TonestepTests/SREngineTests.swift`

Delete `randomDrillType`. `DailySessionBuilder` instead draws specs from the user's current stage via `CurriculumBuilder.drillSpecs`, so sessions cover whatever the curriculum covers rather than four hardcoded modules.

`DrillPlan` carries an optional `DrillSpec` alongside its `drillType`, so `DailySessionView` can dispatch by spec when present.

**Tests to add:**
- A built session never contains the hardcoded `interval_major_third_ascending` sentinel.
- Every plan in a built session carries a valid spec whose answer is among its choices.
- A free-entitlement session references only free-chapter content.

- [ ] Write the failing tests
- [ ] Replace `randomDrillType` with curriculum-backed specs
- [ ] Full suite green
- [ ] Commit

---

## Definition of done

- `CurriculumBuilder` is referenced from app code, not just its own folder.
- `JourneyProgress` is read by at least one view.
- `interval_major_third_ascending` no longer appears in the codebase.
- A stage is playable end to end in the Simulator and persists its result.
- Full suite green.
