import Foundation
import SwiftData

@Model
final class SRItem {
    var drillType: String
    var easeFactor: Double       // SM-2 default 2.5
    var intervalDays: Int        // days until next review
    var repetitions: Int
    var nextReviewDate: Date
    var lastAccuracy: Double

    init(drillType: String) {
        self.drillType = drillType
        self.easeFactor = 2.5
        self.intervalDays = 1
        self.repetitions = 0
        self.nextReviewDate = Date()
        self.lastAccuracy = 0
    }

    var isDue: Bool { nextReviewDate <= Date() }
}
