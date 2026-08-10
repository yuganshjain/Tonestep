import XCTest
@testable import Tonestep

final class CurriculumBuilderTests: XCTestCase {

    func test_free_curriculum_has_seven_chapters() {
        XCTAssertEqual(CurriculumBuilder.chapters(for: .free).count, 7)
    }

    func test_pro_curriculum_has_eleven_chapters() {
        XCTAssertEqual(CurriculumBuilder.chapters(for: .pro).count, 11)
    }

    func test_free_curriculum_has_seventy_stages() {
        XCTAssertEqual(CurriculumBuilder.stages(for: .free).count, 70)
    }

    func test_pro_curriculum_has_one_hundred_twelve_stages() {
        XCTAssertEqual(CurriculumBuilder.stages(for: .pro).count, 112)
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
        // Anchor modules plus any module converted to a spec-driven renderer.
        let anchors: Set<TrainingModule> = [.intervalRecognition, .chordRecognition,
                                            .scaleRecognition, .functionalEar,
                                            .chordProgressions]
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
