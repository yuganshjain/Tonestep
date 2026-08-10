import XCTest
@testable import EarIQ

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
        let e = DifficultyEnvelope(
            poolSteps: [[.interval(.perfectFifth), .interval(.octave)]],
            answerSetStart: 6, answerSetEnd: 6,
            contextStart: .isolated, contextEnd: .isolated,
            voicingStart: [.ascending], voicingEnd: [.ascending],
            registerStart: .fixedMiddle, registerEnd: .fixedMiddle,
            rootStart: .fixedC, rootEnd: .fixedC,
            replaysAtEnd: nil, deadlineAtEnd: nil
        )
        XCTAssertEqual(e.params(atStage: 0, of: 4).answerSetSize, 2)
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
