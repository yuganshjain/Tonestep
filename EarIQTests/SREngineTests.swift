import XCTest
@testable import EarIQ

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
        XCTAssertEqual(EarIQLevel.level(for: 0), 0)
    }

    func test_level_system_title_at_zero_xp() {
        XCTAssertEqual(EarIQLevel.title(for: 0), "Tone Seeker")
    }
}
