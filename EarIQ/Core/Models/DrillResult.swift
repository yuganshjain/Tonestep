import Foundation
import SwiftData

enum TrainingModule: String, CaseIterable, Codable {
    case intervalRecognition = "Interval Recognition"
    case chordRecognition = "Chord Recognition"
    case scaleRecognition = "Scale Recognition"
    case functionalEar = "Functional Ear"
    case chordProgressions = "Chord Progressions"
    case rhythmTrainer = "Rhythm Trainer"
    case melodicDictation = "Melodic Dictation"
    case relativePitch = "Relative Pitch"
    case absolutePitch = "Absolute Pitch"
    case singingPractice = "Singing Practice"
    case noteIdentification = "Note Identification"
    case chordInversions = "Chord Inversions"
    case intervalComparison = "Interval Comparison"
    case errorDetection = "Error Detection"

    var isProOnly: Bool {
        switch self {
        case .intervalRecognition, .chordRecognition, .scaleRecognition,
             .functionalEar, .noteIdentification: return false
        case .chordProgressions, .rhythmTrainer, .melodicDictation,
             .relativePitch, .absolutePitch, .singingPractice,
             .chordInversions, .intervalComparison, .errorDetection: return true
        }
    }

    var systemImage: String {
        switch self {
        case .intervalRecognition: return "arrow.up.right"
        case .chordRecognition: return "music.note"
        case .scaleRecognition: return "waveform.path.ecg"
        case .functionalEar: return "ear.fill"
        case .chordProgressions: return "rectangle.grid.1x2.fill"
        case .rhythmTrainer: return "metronome.fill"
        case .melodicDictation: return "pencil.and.outline"
        case .relativePitch: return "tuningfork"
        case .absolutePitch: return "star.fill"
        case .singingPractice: return "mic.fill"
        case .noteIdentification: return "pianokeys"
        case .chordInversions: return "arrow.up.and.down.and.arrow.left.and.right"
        case .intervalComparison: return "arrow.left.arrow.right"
        case .errorDetection: return "exclamationmark.triangle.fill"
        }
    }

    var isComingSoon: Bool { false }

    var description: String {
        switch self {
        case .intervalRecognition: return "Recognize the distance between two notes"
        case .chordRecognition: return "Identify chord types and qualities"
        case .scaleRecognition: return "Hear and name major, minor, and modal scales"
        case .functionalEar: return "Identify scale degrees in a key context"
        case .chordProgressions: return "Recognize common chord progressions"
        case .rhythmTrainer: return "Identify and clap back rhythmic patterns"
        case .melodicDictation: return "Reconstruct melodies you hear"
        case .relativePitch: return "Identify notes relative to a given root"
        case .absolutePitch: return "Identify notes without any reference"
        case .singingPractice: return "Sing notes using your microphone"
        case .noteIdentification: return "Name the note you hear by pitch"
        case .chordInversions: return "Identify root, 1st, and 2nd inversions"
        case .intervalComparison: return "Decide which of two intervals is wider"
        case .errorDetection: return "Find the wrong note in a 4-beat melody"
        }
    }
}

@Model
final class DrillResult {
    var id: UUID
    var moduleRaw: String
    var drillType: String
    var wasCorrect: Bool
    var responseTime: TimeInterval
    var timestamp: Date

    var module: TrainingModule {
        TrainingModule(rawValue: moduleRaw) ?? .intervalRecognition
    }

    init(module: TrainingModule, drillType: String, wasCorrect: Bool, responseTime: TimeInterval) {
        self.id = UUID()
        self.moduleRaw = module.rawValue
        self.drillType = drillType
        self.wasCorrect = wasCorrect
        self.responseTime = responseTime
        self.timestamp = Date()
    }
}

@Model
final class DailySessionRecord {
    var id: UUID
    var date: Date
    var xpEarned: Int
    var totalDrills: Int
    var correctDrills: Int
    var completedAt: Date?

    var accuracy: Double {
        guard totalDrills > 0 else { return 0 }
        return Double(correctDrills) / Double(totalDrills)
    }

    init(date: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.xpEarned = 0
        self.totalDrills = 0
        self.correctDrills = 0
    }
}
