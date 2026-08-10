import XCTest
@testable import EarIQ

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
