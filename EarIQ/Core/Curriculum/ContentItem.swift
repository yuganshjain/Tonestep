import Foundation

/// Everything a drill can ask the user to identify.
/// Backed by the existing enums in MusicTheory.swift.
enum ContentItem: Hashable, Codable {
    case interval(Interval)
    case chord(ChordQuality)
    case scale(ScaleType)
    case degree(ScaleDegree)

    /// Join key for DrillResult and SRItem. Must match the legacy string formats
    /// already persisted, or spaced-repetition history stops matching.
    var drillType: String {
        switch self {
        case .interval(let i): return i.drillType
        case .chord(let c):    return c.drillType
        case .scale(let s):    return s.drillType
        case .degree(let d):   return d.drillType
        }
    }

    var displayName: String {
        switch self {
        case .interval(let i): return i.name
        case .chord(let c):    return c.rawValue
        case .scale(let s):    return s.rawValue
        case .degree(let d):   return d.solfege
        }
    }

    var module: TrainingModule {
        switch self {
        case .interval: return .intervalRecognition
        case .chord:    return .chordRecognition
        case .scale:    return .scaleRecognition
        case .degree:   return .functionalEar
        }
    }

    /// Semitone content, used by ConfusionMatrix to measure perceptual similarity.
    var semitones: [Int] {
        switch self {
        case .interval(let i): return [i.rawValue]
        case .chord(let c):    return c.semitones
        case .scale(let s):    return s.semitones
        case .degree(let d):   return [d.semitoneFromRoot]
        }
    }
}

/// Purchase state. Passed explicitly rather than read from StoreManager so the
/// curriculum stays pure and testable.
enum Entitlement {
    case free, pro
}
