import Foundation

enum HarmonicContext: String, Codable, CaseIterable {
    /// Play a I-IV-V-I cadence first so the key centre is established.
    case cadencePrimer
    /// Sustain the root underneath.
    case droneRoot
    /// No reference at all.
    case isolated

    var difficultyWeight: Double {
        switch self {
        case .cadencePrimer: return 0
        case .droneRoot:     return 4
        case .isolated:      return 9
        }
    }
}

enum VoicingMode: String, Codable, CaseIterable, Comparable {
    case ascending, descending, harmonic

    /// Suffix used in legacy drillType strings, e.g. interval_major_3rd_ascending.
    var legacySuffix: String { rawValue }

    static func < (lhs: VoicingMode, rhs: VoicingMode) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum RegisterSpan: String, Codable, CaseIterable {
    case fixedMiddle, twoOctaves, threeOctaves

    var midiRange: ClosedRange<UInt8> {
        switch self {
        case .fixedMiddle:  return 60...60
        case .twoOctaves:   return 52...76
        case .threeOctaves: return 45...81
        }
    }

    var difficultyWeight: Double {
        switch self {
        case .fixedMiddle:  return 0
        case .twoOctaves:   return 3
        case .threeOctaves: return 6
        }
    }
}

enum RootPolicy: String, Codable, CaseIterable {
    /// Always C. Lets users answer from absolute memory.
    case fixedC
    /// Randomised, which forces genuinely relative hearing.
    case randomRoot
}

enum TimbreMode: String, Codable, CaseIterable {
    case primary, mixed
}

/// Describes the *space* of drills a stage draws from.
/// A single resolved question is a DrillSpec, sampled from this.
struct DifficultyParams: Codable, Equatable {
    var contentPool: [ContentItem]
    var answerSetSize: Int
    var harmonicContext: HarmonicContext
    var voicings: Set<VoicingMode>
    var registerSpan: RegisterSpan
    var rootPolicy: RootPolicy
    var replaysAllowed: Int?             // nil = unlimited
    var responseDeadline: TimeInterval?  // nil = untimed
    var timbre: TimbreMode

    /// Scalar used to order stages and to assert the curve is monotonic in tests.
    /// Weights are tuned so no single axis dominates.
    var difficultyScore: Double {
        var score = 0.0
        score += ConfusionMatrix.poolDifficulty(contentPool) * 30
        score += Double(contentPool.count) * 1.5
        score += Double(answerSetSize) * 1.0
        score += harmonicContext.difficultyWeight
        score += Double(voicings.count) * 3
        score += registerSpan.difficultyWeight
        score += rootPolicy == .randomRoot ? 6 : 0
        if let replays = replaysAllowed {
            score += Double(max(0, 3 - replays)) * 2
        }
        score += responseDeadline != nil ? 5 : 0
        score += timbre == .mixed ? 4 : 0
        return score
    }
}
