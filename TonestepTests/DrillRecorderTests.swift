import XCTest
import SwiftData
@testable import Tonestep

final class DrillRecorderTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: DrillResult.self, DailySessionRecord.self, SRItem.self,
                JourneyProgress.self, StageRecord.self,
            configurations: config
        )
        context = ModelContext(container)
    }

    private func record(_ correct: Bool, drillType: String = "interval_major_3rd_ascending") {
        DrillRecorder.record(module: .intervalRecognition, drillType: drillType,
                             correct: correct, responseTime: 1.5,
                             context: context, userProfile: nil)
    }

    func test_records_a_drill_result() throws {
        record(true)
        let results = try context.fetch(FetchDescriptor<DrillResult>())
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results[0].wasCorrect)
        XCTAssertEqual(results[0].module, .intervalRecognition)
    }

    /// The bug this type exists to fix: standalone modules recorded results but
    /// never scheduled a review.
    func test_creates_a_spaced_repetition_item() throws {
        record(true)
        let items = try context.fetch(FetchDescriptor<SRItem>())
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].drillType, "interval_major_3rd_ascending")
    }

    func test_reuses_the_existing_sr_item_for_the_same_drill_type() throws {
        record(true)
        record(true)
        record(true)
        let items = try context.fetch(FetchDescriptor<SRItem>())
        XCTAssertEqual(items.count, 1, "should grade one item, not create duplicates")
        XCTAssertEqual(items[0].repetitions, 3)
    }

    func test_separate_drill_types_get_separate_items() throws {
        record(true, drillType: "interval_major_3rd_ascending")
        record(true, drillType: "chord_major")
        XCTAssertEqual(try context.fetch(FetchDescriptor<SRItem>()).count, 2)
    }

    func test_correct_answer_extends_the_review_interval() throws {
        record(true)
        record(true)
        record(true)
        let item = try XCTUnwrap(try context.fetch(FetchDescriptor<SRItem>()).first)
        XCTAssertGreaterThan(item.intervalDays, 1)
    }

    func test_wrong_answer_resets_the_review_interval() throws {
        record(true)
        record(true)
        record(true)
        record(false)
        let item = try XCTUnwrap(try context.fetch(FetchDescriptor<SRItem>()).first)
        XCTAssertEqual(item.repetitions, 0)
        XCTAssertEqual(item.intervalDays, 1)
    }

    func test_records_last_accuracy() throws {
        record(false)
        let item = try XCTUnwrap(try context.fetch(FetchDescriptor<SRItem>()).first)
        XCTAssertEqual(item.lastAccuracy, 0, accuracy: 0.001)
    }

    func test_awards_xp_only_when_correct() {
        let profile = UserProfileStore()
        let before = profile.xp
        DrillRecorder.record(module: .intervalRecognition, drillType: "t", correct: false,
                             responseTime: 1, context: context, userProfile: profile)
        XCTAssertEqual(profile.xp, before, "a wrong answer must not award XP")

        DrillRecorder.record(module: .intervalRecognition, drillType: "t", correct: true,
                             responseTime: 1, context: context, userProfile: profile)
        XCTAssertGreaterThan(profile.xp, before)
    }

    func test_works_without_a_user_profile() throws {
        DrillRecorder.record(module: .rhythmTrainer, drillType: "rhythm_qqqq", correct: true,
                             responseTime: 1, context: context, userProfile: nil)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DrillResult>()).count, 1)
    }
}
