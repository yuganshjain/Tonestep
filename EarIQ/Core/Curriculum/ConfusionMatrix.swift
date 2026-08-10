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

    /// Mean pairwise confusability across the pool. 0 for pools of 0 or 1.
    static func poolDifficulty(_ pool: [ContentItem]) -> Double {
        guard pool.count > 1 else { return 0 }
        var total = 0.0
        var pairs = 0
        for i in 0..<pool.count {
            for j in (i + 1)..<pool.count {
                total += confusability(pool[i], pool[j])
                pairs += 1
            }
        }
        return pairs == 0 ? 0 : total / Double(pairs)
    }

    private static func jaccard(_ a: Set<Int>, _ b: Set<Int>) -> Double {
        let union = a.union(b)
        guard !union.isEmpty else { return 0 }
        return Double(a.intersection(b).count) / Double(union.count)
    }

    private static func sameKind(_ a: ContentItem, _ b: ContentItem) -> Bool {
        switch (a, b) {
        case (.interval, .interval), (.chord, .chord),
             (.scale, .scale), (.degree, .degree):
            return true
        default:
            return false
        }
    }
}
