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
