import Foundation

/// Measures how easily two items are mistaken for each other by ear.
/// Difficulty should track perceptual distance, not item count: adding the
/// octave to a pool is trivial, adding the perfect 4th beside the perfect 5th
/// is genuinely hard.
enum ConfusionMatrix {

    /// 0 = never confused, 1 = identical.
    static func confusability(_ a: ContentItem, _ b: ContentItem) -> Double {
        guard sameKind(a, b) else { return 0 }
        if a == b { return 1 }

        switch (a, b) {
        case (.interval(let x), .interval(let y)):
            return 1.0 - Double(abs(x.rawValue - y.rawValue)) / 12.0
        case (.degree(let x), .degree(let y)):
            return 1.0 - Double(abs(x.semitoneFromRoot - y.semitoneFromRoot)) / 11.0
        default:
            // Chords and scales are sets of pitches: Jaccard similarity.
            return jaccard(Set(a.semitones), Set(b.semitones))
        }
    }

    /// Hardest discrimination the pool demands: the maximum pairwise
    /// confusability. 0 for pools of 0 or 1.
    ///
    /// Deliberately max rather than mean. A mean *falls* as a pool grows —
    /// adding distant items dilutes it — which made larger pools score as
    /// easier and broke the monotonic difficulty curve. It is also the better
    /// model: a pool is hard because of the closest pair you must tell apart,
    /// not the average distance. Pool breadth is scored separately by the
    /// contentPool.count term in DifficultyParams.difficultyScore.
    static func poolDifficulty(_ pool: [ContentItem]) -> Double {
        guard pool.count > 1 else { return 0 }
        var hardest = 0.0
        for i in 0..<pool.count {
            for j in (i + 1)..<pool.count {
                hardest = max(hardest, confusability(pool[i], pool[j]))
            }
        }
        return hardest
    }

    private static func jaccard(_ a: Set<Int>, _ b: Set<Int>) -> Double {
        let union = a.union(b)
        guard !union.isEmpty else { return 0 }
        return Double(a.intersection(b).count) / Double(union.count)
    }

    private static func sameKind(_ a: ContentItem, _ b: ContentItem) -> Bool {
        switch (a, b) {
        case (.interval, .interval), (.chord, .chord),
             (.scale, .scale), (.degree, .degree),
             (.progression, .progression):
            return true
        default:
            return false
        }
    }
}
