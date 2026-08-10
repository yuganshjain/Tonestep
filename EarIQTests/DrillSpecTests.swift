import XCTest
@testable import EarIQ

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
        let s = DrillSpec(
            module: item.module, item: item, voicing: .ascending, rootMidi: 60,
            choices: [.interval(.perfectFifth), item, .interval(.octave)],
            harmonicContext: .isolated, replaysAllowed: nil, responseDeadline: nil
        )
        XCTAssertEqual(s.correctChoiceIndex, 1)
    }
}
