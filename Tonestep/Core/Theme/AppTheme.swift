import SwiftUI

extension Color {
    static let appPurple     = Color(red: 0.357, green: 0.310, blue: 0.812)
    static let appPurpleDark = Color(red: 0.176, green: 0.106, blue: 0.412)
    static let appPurpleMid  = Color(red: 0.267, green: 0.196, blue: 0.620)
}

extension TrainingModule {
    var pastelColor: Color {
        switch self {
        case .intervalRecognition:  return Color(red: 1.00, green: 0.84, blue: 0.90)
        case .chordRecognition:     return Color(red: 0.76, green: 0.94, blue: 0.91)
        case .scaleRecognition:     return Color(red: 1.00, green: 0.95, blue: 0.80)
        case .jazzChords:           return Color(red: 0.91, green: 0.88, blue: 1.00)
        case .rhythmTrainer:        return Color(red: 1.00, green: 0.89, blue: 0.84)
        case .melodicDictation:     return Color(red: 0.84, green: 0.92, blue: 0.97)
        case .chordProgressions:    return Color(red: 0.90, green: 0.84, blue: 1.00)
        case .singingPractice:      return Color(red: 1.00, green: 0.84, blue: 0.93)
        case .noteIdentification:   return Color(red: 0.84, green: 0.97, blue: 0.84)
        case .chordInversions:      return Color(red: 0.97, green: 0.84, blue: 1.00)
        case .intervalComparison:   return Color(red: 0.84, green: 0.90, blue: 1.00)
        case .errorDetection:       return Color(red: 1.00, green: 0.84, blue: 0.84)
        case .relativePitch:        return Color(red: 0.84, green: 1.00, blue: 0.90)
        case .absolutePitch:        return Color(red: 1.00, green: 0.93, blue: 0.84)
        case .functionalEar:        return Color(red: 1.00, green: 0.84, blue: 0.76)
        }
    }

    var moduleEmoji: String {
        switch self {
        case .intervalRecognition:  return "🎼"
        case .chordRecognition:     return "🎹"
        case .scaleRecognition:     return "🎸"
        case .jazzChords:           return "🎷"
        case .rhythmTrainer:        return "🥁"
        case .melodicDictation:     return "🎵"
        case .chordProgressions:    return "🎶"
        case .singingPractice:      return "🎤"
        case .noteIdentification:   return "🎯"
        case .chordInversions:      return "🎺"
        case .intervalComparison:   return "⚡"
        case .errorDetection:       return "🔍"
        case .relativePitch:        return "📻"
        case .absolutePitch:        return "🌟"
        case .functionalEar:        return "👂"
        }
    }

    static let pastelText    = Color(red: 0.18, green: 0.11, blue: 0.41)
    static let pastelSubtext = Color(red: 0.35, green: 0.25, blue: 0.55)
}
