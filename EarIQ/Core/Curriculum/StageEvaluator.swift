import Foundation

struct StageOutcome: Equatable {
    let passed: Bool
    let accuracy: Double
    let stars: Int
}

enum StageEvaluator {
    static func evaluate(results: [DrillResult], criteria: PassCriteria) -> StageOutcome {
        let total = results.count
        guard total > 0 else {
            return StageOutcome(passed: false, accuracy: 0, stars: 0)
        }

        let accuracy = Double(results.filter(\.wasCorrect).count) / Double(total)

        guard total >= criteria.minQuestions else {
            return StageOutcome(passed: false, accuracy: accuracy, stars: 0)
        }

        let passed = accuracy >= criteria.minAccuracy
        let stars = passed ? criteria.starThresholds.filter { accuracy >= $0 }.count : 0
        return StageOutcome(passed: passed, accuracy: accuracy, stars: stars)
    }
}
