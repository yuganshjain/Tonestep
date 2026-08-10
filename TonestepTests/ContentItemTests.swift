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
