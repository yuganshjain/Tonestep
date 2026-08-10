import Foundation
import SwiftData

/// Where the user currently is in the curriculum.
/// Stored as chapter id plus index, never a global stage number, so inserting a
/// chapter in Phase 2 cannot corrupt saved progress.
@Model
final class JourneyProgress {
    var currentChapterId: String
    var currentIndexInChapter: Int
    var lastUpdated: Date

    init(currentChapterId: String, currentIndexInChapter: Int = 0) {
        self.currentChapterId = currentChapterId
        self.currentIndexInChapter = currentIndexInChapter
        self.lastUpdated = Date()
    }

    var currentStageId: String { "\(currentChapterId)-\(currentIndexInChapter)" }

    func advance(to stage: Stage) {
        currentChapterId = stage.chapterId
        currentIndexInChapter = stage.indexInChapter
        lastUpdated = Date()
    }
}

/// Best result achieved on a single stage.
@Model
final class StageRecord {
    var stageId: String
    var bestAccuracy: Double
    var stars: Int
    var passedAt: Date?

    init(stageId: String) {
        self.stageId = stageId
        self.bestAccuracy = 0
        self.stars = 0
        self.passedAt = nil
    }

    func record(outcome: StageOutcome) {
        if outcome.accuracy > bestAccuracy {
            bestAccuracy = outcome.accuracy
            stars = outcome.stars
        }
        if outcome.passed && passedAt == nil {
            passedAt = Date()
        }
    }
}
