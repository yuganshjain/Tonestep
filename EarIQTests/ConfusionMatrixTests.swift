import XCTest
@testable import EarIQ

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
