import XCTest
@testable import Tonestep

final class DifficultyParamsTests: XCTestCase {

    private func baseline() -> DifficultyParams {
        DifficultyParams(
            contentPool: [.interval(.perfectFifth), .interval(.octave)],
            answerSetSize: 2,
            harmonicContext: .cadencePrimer,
            voicings: [.ascending],
            registerSpan: .fixedMiddle,
            rootPolicy: .fixedC,
            replaysAllowed: nil,
            responseDeadline: nil,
            timbre: .primary
        )
    }

    func test_larger_pool_scores_higher() {
        var bigger = baseline()
        bigger.contentPool = [.interval(.perfectFifth), .interval(.octave), .interval(.majorThird)]
        XCTAssertGreaterThan(bigger.difficultyScore, baseline().difficultyScore)
    }

    func test_isolated_context_scores_higher_than_primer() {
        var harder = baseline()
        harder.harmonicContext = .isolated
        XCTAssertGreaterThan(harder.difficultyScore, baseline().difficultyScore)
    }

    func test_random_root_scores_higher_than_fixed() {
        var harder = baseline()
        harder.rootPolicy = .randomRoot
        XCTAssertGreaterThan(harder.difficultyScore, baseline().difficultyScore)
    }

    func test_more_voicings_score_higher() {
        var harder = baseline()
        harder.voicings = [.ascending, .descending, .harmonic]
        XCTAssertGreaterThan(harder.difficultyScore, baseline().difficultyScore)
    }

    func test_wider_register_scores_higher() {
        var harder = baseline()
        harder.registerSpan = .threeOctaves
        XCTAssertGreaterThan(harder.difficultyScore, baseline().difficultyScore)
    }

    func test_deadline_scores_higher() {
        var harder = baseline()
        harder.responseDeadline = 8
        XCTAssertGreaterThan(harder.difficultyScore, baseline().difficultyScore)
    }

    func test_fewer_replays_score_higher() {
        var harder = baseline()
        harder.replaysAllowed = 0
        XCTAssertGreaterThan(harder.difficultyScore, baseline().difficultyScore)
    }

    func test_confusable_pool_scores_higher_than_distant_pool_of_same_size() {
        var confusable = baseline()
        confusable.contentPool = [.interval(.perfectFifth), .interval(.perfectFourth)]
        var distant = baseline()
        distant.contentPool = [.interval(.perfectFifth), .interval(.minorSecond)]
        XCTAssertGreaterThan(confusable.difficultyScore, distant.difficultyScore)
    }

    func test_fixedMiddle_register_is_single_note() {
        XCTAssertEqual(RegisterSpan.fixedMiddle.midiRange, 60...60)
    }
}
