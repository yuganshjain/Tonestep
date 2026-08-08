import Foundation

// MARK: - Intervals

enum Interval: Int, CaseIterable, Codable {
    case unison = 0
    case minorSecond = 1
    case majorSecond = 2
    case minorThird = 3
    case majorThird = 4
    case perfectFourth = 5
    case tritone = 6
    case perfectFifth = 7
    case minorSixth = 8
    case majorSixth = 9
    case minorSeventh = 10
    case majorSeventh = 11
    case octave = 12

    var name: String {
        switch self {
        case .unison: return "Unison"
        case .minorSecond: return "Minor 2nd"
        case .majorSecond: return "Major 2nd"
        case .minorThird: return "Minor 3rd"
        case .majorThird: return "Major 3rd"
        case .perfectFourth: return "Perfect 4th"
        case .tritone: return "Tritone"
        case .perfectFifth: return "Perfect 5th"
        case .minorSixth: return "Minor 6th"
        case .majorSixth: return "Major 6th"
        case .minorSeventh: return "Minor 7th"
        case .majorSeventh: return "Major 7th"
        case .octave: return "Octave"
        }
    }

    var drillType: String { "interval_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))" }

    // Famous song mnemonic for recognition
    var mnemonic: String {
        switch self {
        case .unison: return "Same note"
        case .minorSecond: return "Jaws theme"
        case .majorSecond: return "Happy Birthday"
        case .minorThird: return "Smoke on the Water"
        case .majorThird: return "When the Saints"
        case .perfectFourth: return "Here Comes the Bride"
        case .tritone: return "The Simpsons"
        case .perfectFifth: return "Star Wars theme"
        case .minorSixth: return "The Entertainer"
        case .majorSixth: return "My Bonnie"
        case .minorSeventh: return "Somewhere (West Side Story)"
        case .majorSeventh: return "Take On Me"
        case .octave: return "Somewhere Over the Rainbow"
        }
    }
}

enum IntervalDirection: String, CaseIterable, Codable {
    case ascending = "Ascending"
    case descending = "Descending"
    case harmonic = "Harmonic"
}

// MARK: - Chords

enum ChordQuality: String, CaseIterable, Codable {
    case major = "Major"
    case minor = "Minor"
    case diminished = "Diminished"
    case augmented = "Augmented"
    case dominantSeventh = "Dom 7"
    case majorSeventh = "Maj 7"
    case minorSeventh = "Min 7"
    case suspendedSecond = "Sus 2"
    case suspendedFourth = "Sus 4"
    case addedNinth = "Add 9"

    var semitones: [Int] {
        switch self {
        case .major:           return [0, 4, 7]
        case .minor:           return [0, 3, 7]
        case .diminished:      return [0, 3, 6]
        case .augmented:       return [0, 4, 8]
        case .dominantSeventh: return [0, 4, 7, 10]
        case .majorSeventh:    return [0, 4, 7, 11]
        case .minorSeventh:    return [0, 3, 7, 10]
        case .suspendedSecond: return [0, 2, 7]
        case .suspendedFourth: return [0, 5, 7]
        case .addedNinth:      return [0, 4, 7, 14]
        }
    }

    var isProOnly: Bool {
        switch self {
        case .major, .minor, .diminished, .augmented: return false
        default: return true
        }
    }

    var drillType: String { "chord_\(rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))" }
}

// MARK: - Scales

enum ScaleType: String, CaseIterable, Codable {
    case major = "Major"
    case naturalMinor = "Natural Minor"
    case harmonicMinor = "Harmonic Minor"
    case melodicMinor = "Melodic Minor"
    case dorian = "Dorian"
    case phrygian = "Phrygian"
    case lydian = "Lydian"
    case mixolydian = "Mixolydian"
    case locrian = "Locrian"
    case majorPentatonic = "Major Pentatonic"
    case minorPentatonic = "Minor Pentatonic"
    case blues = "Blues"

    var semitones: [Int] {
        switch self {
        case .major:           return [0, 2, 4, 5, 7, 9, 11, 12]
        case .naturalMinor:    return [0, 2, 3, 5, 7, 8, 10, 12]
        case .harmonicMinor:   return [0, 2, 3, 5, 7, 8, 11, 12]
        case .melodicMinor:    return [0, 2, 3, 5, 7, 9, 11, 12]
        case .dorian:          return [0, 2, 3, 5, 7, 9, 10, 12]
        case .phrygian:        return [0, 1, 3, 5, 7, 8, 10, 12]
        case .lydian:          return [0, 2, 4, 6, 7, 9, 11, 12]
        case .mixolydian:      return [0, 2, 4, 5, 7, 9, 10, 12]
        case .locrian:         return [0, 1, 3, 5, 6, 8, 10, 12]
        case .majorPentatonic: return [0, 2, 4, 7, 9, 12]
        case .minorPentatonic: return [0, 3, 5, 7, 10, 12]
        case .blues:           return [0, 3, 5, 6, 7, 10, 12]
        }
    }

    var freeForAll: Bool {
        switch self {
        case .major, .naturalMinor, .majorPentatonic: return true
        default: return false
        }
    }

    var drillType: String { "scale_\(rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))" }
}

// MARK: - Scale Degrees (Functional Ear)

enum ScaleDegree: Int, CaseIterable, Codable {
    case do_ = 1, re = 2, mi = 3, fa = 4, sol = 5, la = 6, ti = 7

    var solfege: String {
        switch self {
        case .do_: return "Do"
        case .re: return "Re"
        case .mi: return "Mi"
        case .fa: return "Fa"
        case .sol: return "Sol"
        case .la: return "La"
        case .ti: return "Ti"
        }
    }

    var numberLabel: String { "\(rawValue)" }

    var semitoneFromRoot: Int {
        [0, 2, 4, 5, 7, 9, 11][rawValue - 1]
    }

    var drillType: String { "functional_degree_\(solfege.lowercased())" }

    // Degrees in the beginner progression unlock order
    static let beginnerSet: [ScaleDegree] = [.do_, .sol, .mi]
    static let intermediateSet: [ScaleDegree] = [.do_, .sol, .mi, .la, .re]
    static let fullSet: [ScaleDegree] = ScaleDegree.allCases

    var stabilityDescription: String {
        switch self {
        case .do_: return "Tonic — very stable"
        case .re: return "Supertonic — slightly tense"
        case .mi: return "Mediant — stable"
        case .fa: return "Subdominant — mild tension"
        case .sol: return "Dominant — stable, wants to resolve"
        case .la: return "Submediant — stable"
        case .ti: return "Leading tone — strong tension"
        }
    }
}

// MARK: - Notes

enum Note: Int, CaseIterable {
    case c = 60, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b

    var name: String {
        ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][rawValue - 60]
    }

    static func midi(note: Note, octave: Int) -> Int {
        (octave + 1) * 12 + note.rawValue - 60
    }
}
