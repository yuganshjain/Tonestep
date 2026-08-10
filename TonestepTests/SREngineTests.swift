import XCTest
@testable import Tonestep

final class SREngineTests: XCTestCase {
    func test_grade_correct_increases_interval() {
        let item = SRItem(drillType: "test")
        item.repetitions = 1
        item.intervalDays = 1
        SREngine.grade(for: item, quality: 5)
        XCTAssertGreaterThan(item.intervalDays, 1)
    }

    func test_grade_incorrect_resets_interval() {
        let item = SRItem(drillType: "test")
        item.repetitions = 5
        item.intervalDays = 20
        SREngine.grade(for: item, quality: 0)
        XCTAssertEqual(item.repetitions, 0)
        XCTAssertEqual(item.intervalDays, 1)
    }

    func test_easeFactor_never_below_1_3() {
        let item = SRItem(drillType: "test")
        for _ in 0..<10 {
            SREngine.grade(for: item, quality: 0)
        }
        XCTAssertGreaterThanOrEqual(item.easeFactor, 1.3)
    }

    func test_quality_perfect_fast_response_is_5() {
        let quality = SREngine.quality(from: 1.0, responseTime: 1.5)
        XCTAssertEqual(quality, 5)
    }

    func test_quality_wrong_is_0() {
        let quality = SREngine.quality(from: 0.0, responseTime: 2.0)
        XCTAssertEqual(quality, 0)
    }
}

final class MusicTheoryTests: XCTestCase {
    func test_major_chord_semitones() {
        XCTAssertEqual(ChordQuality.major.semitones, [0, 4, 7])
    }

    func test_minor_chord_semitones() {
        XCTAssertEqual(ChordQuality.minor.semitones, [0, 3, 7])
    }

    func test_scale_degree_semitone_do() {
        XCTAssertEqual(ScaleDegree.do_.semitoneFromRoot, 0)
    }

    func test_scale_degree_semitone_sol() {
        XCTAssertEqual(ScaleDegree.sol.semitoneFromRoot, 7)
    }

    func test_level_system_level0_at_zero_xp() {
        XCTAssertEqual(TonestepLevel.level(for: 0), 0)
    }

    func test_level_system_title_at_zero_xp() {
        XCTAssertEqual(TonestepLevel.title(for: 0), "Tone Seeker")
    }
}

// MARK: - Daily session now covers the whole curriculum

final class DailySessionBuilderTests: XCTestCase {

    private func session(isPro: Bool) -> [DrillPlan] {
        DailySessionBuilder.buildSession(
            srItems: [], recentResults: [], targetCount: 12, isPro: isPro
        )
    }

    /// Regression: the old randomDrillType returned this literal for 11 of the
    /// 15 modules, so most of the app could never appear in a daily session.
    func test_session_never_contains_the_hardcoded_sentinel() {
        for plan in session(isPro: true) {
            XCTAssertNotEqual(plan.drillType, "interval_major_third_ascending")
        }
    }

    func test_session_returns_the_requested_count() {
        XCTAssertEqual(session(isPro: true).count, 12)
    }

    func test_curriculum_plans_carry_a_valid_spec() throws {
        let curriculumPlans = session(isPro: true).filter { $0.source == .random }
        XCTAssertFalse(curriculumPlans.isEmpty, "expected the filler to come from the curriculum")
        for plan in curriculumPlans {
            let spec = try XCTUnwrap(plan.spec)
            XCTAssertNotNil(spec.correctChoiceIndex, "answer missing from choices")
        }
    }

    func test_plan_drillType_matches_its_spec() {
        for plan in session(isPro: true) {
            if let spec = plan.spec {
                XCTAssertEqual(plan.drillType, spec.drillType)
            }
        }
    }

    func test_free_session_only_uses_free_curriculum_content() {
        let freeItems = Set(CurriculumBuilder.stages(for: .free)
            .flatMap { $0.params.contentPool })
        for plan in session(isPro: false) {
            if let spec = plan.spec {
                XCTAssertTrue(freeItems.contains(spec.item), "pro content in a free session")
            }
        }
    }
}
