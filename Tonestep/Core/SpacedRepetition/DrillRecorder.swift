import Foundation
import SwiftData

/// The single place a completed drill is recorded.
///
/// Before this existed, three different paths did three different things:
/// session views recorded a result, awarded XP and graded spaced repetition;
/// the standalone modules recorded a result and XP but never graded SR, so
/// practising them scheduled no reviews; and free practice on the four main
/// modules passed `onComplete: { _, _ in }` and discarded everything.
enum DrillRecorder {

    /// XP per correct answer. Matches the daily session's long-standing rate.
    static let xpPerCorrect = 2

    @discardableResult
    static func record(
        module: TrainingModule,
        drillType: String,
        correct: Bool,
        responseTime: TimeInterval,
        context: ModelContext,
        userProfile: UserProfileStore?
    ) -> DrillResult {
        let result = DrillResult(module: module, drillType: drillType,
                                 wasCorrect: correct, responseTime: responseTime)
        context.insert(result)

        gradeSpacedRepetition(drillType: drillType, correct: correct,
                              responseTime: responseTime, context: context)

        if correct {
            userProfile?.addXP(xpPerCorrect)
        }
        return result
    }

    /// Grade an already-inserted result. Used by the standalone modules, which
    /// each award their own XP and so cannot use `record` wholesale.
    static func grade(_ result: DrillResult, context: ModelContext) {
        gradeSpacedRepetition(drillType: result.drillType,
                              correct: result.wasCorrect,
                              responseTime: result.responseTime,
                              context: context)
    }

    /// Fetch-or-create the SRItem for this drill type and grade it.
    private static func gradeSpacedRepetition(
        drillType: String,
        correct: Bool,
        responseTime: TimeInterval,
        context: ModelContext
    ) {
        let descriptor = FetchDescriptor<SRItem>(
            predicate: #Predicate { $0.drillType == drillType }
        )
        let item = (try? context.fetch(descriptor))?.first ?? {
            let created = SRItem(drillType: drillType)
            context.insert(created)
            return created
        }()

        item.lastAccuracy = correct ? 1 : 0
        SREngine.grade(for: item,
                       quality: SREngine.quality(from: correct ? 1 : 0,
                                                 responseTime: responseTime))
    }
}
