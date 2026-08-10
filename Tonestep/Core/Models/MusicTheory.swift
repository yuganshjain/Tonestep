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

// MARK: - Chord Progressions

struct ChordProgression: Identifiable, Equatable, Hashable, Codable {
    /// Identity is the id alone — the other fields are fixed lookup data, and
    /// hashing them all would make ContentItem needlessly expensive.
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: ChordProgression, rhs: ChordProgression) -> Bool { lhs.id == rhs.id }

    let id: String
    let name: String
    let romanNumerals: [String]
    let rootOffsets: [Int]
    let qualities: [ChordQuality]
    let description: String
    let genre: String

    static let all: [ChordProgression] = [
        ChordProgression(id: "1451", name: "I–IV–V–I",       romanNumerals: ["I","IV","V","I"],
                         rootOffsets: [0,5,7,0], qualities: [.major,.major,.major,.major],
                         description: "The classic blues & rock foundation", genre: "Blues / Rock"),
        ChordProgression(id: "1564", name: "I–V–vi–IV",      romanNumerals: ["I","V","vi","IV"],
                         rootOffsets: [0,7,9,5], qualities: [.major,.major,.minor,.major],
                         description: "The 'four chord song' — pop everywhere", genre: "Pop"),
        ChordProgression(id: "2501", name: "ii–V–I",         romanNumerals: ["ii","V","I"],
                         rootOffsets: [2,7,0], qualities: [.minor,.major,.major],
                         description: "The jazz cornerstone", genre: "Jazz"),
        ChordProgression(id: "1645", name: "I–vi–IV–V",      romanNumerals: ["I","vi","IV","V"],
                         rootOffsets: [0,9,5,7], qualities: [.major,.minor,.major,.major],
                         description: "'50s doo-wop progression", genre: "Classic / Pop"),
        ChordProgression(id: "6415", name: "vi–IV–I–V",      romanNumerals: ["vi","IV","I","V"],
                         rootOffsets: [9,5,0,7], qualities: [.minor,.major,.major,.major],
                         description: "Modern pop minor feel", genre: "Pop / Indie"),
        ChordProgression(id: "1415", name: "I–IV–I–V",       romanNumerals: ["I","IV","I","V"],
                         rootOffsets: [0,5,0,7], qualities: [.major,.major,.major,.major],
                         description: "12-bar blues variant", genre: "Blues"),
        ChordProgression(id: "1b7b6", name: "i–VII–VI–VII",  romanNumerals: ["i","VII","VI","VII"],
                         rootOffsets: [0,10,8,10], qualities: [.minor,.major,.major,.major],
                         description: "Andalusian cadence — flamenco & rock", genre: "Flamenco / Rock"),
    ]
}

// MARK: - Rhythm Patterns

struct RhythmPattern: Identifiable, Equatable {
    let id: String
    let name: String
    let beats: [RhythmBeat]
    let bpm: Int

    enum RhythmBeat: Equatable {
        case quarter, eighth, sixteenth, half, rest
        var duration: Double {
            switch self { case .quarter: return 0.5; case .eighth: return 0.25; case .sixteenth: return 0.125; case .half: return 1.0; case .rest: return 0.5 }
        }
        var symbol: String {
            switch self { case .quarter: return "♩"; case .eighth: return "♪"; case .sixteenth: return "𝅘𝅥𝅯"; case .half: return "𝅗𝅥"; case .rest: return "𝄽" }
        }
        var isRest: Bool { self == .rest }
    }

    static let beginner: [RhythmPattern] = [
        RhythmPattern(id: "qqqq",  name: "Four Quarters",  beats: [.quarter,.quarter,.quarter,.quarter], bpm: 80),
        RhythmPattern(id: "qqeq",  name: "Syncopated",     beats: [.quarter,.quarter,.eighth,.eighth,.quarter], bpm: 80),
        RhythmPattern(id: "hqq",   name: "Half-Quarter",   beats: [.half,.quarter,.quarter], bpm: 80),
        RhythmPattern(id: "eeeeqq",name: "Eighth Groove",  beats: [.eighth,.eighth,.eighth,.eighth,.quarter,.quarter], bpm: 80),
    ]
    static let intermediate: [RhythmPattern] = [
        RhythmPattern(id: "qreq",  name: "Rest Pattern",   beats: [.quarter,.rest,.eighth,.eighth,.quarter], bpm: 90),
        RhythmPattern(id: "eqeeq", name: "Upbeat Feel",    beats: [.eighth,.quarter,.eighth,.eighth,.quarter,.eighth], bpm: 90),
        RhythmPattern(id: "qeehq", name: "Swing Feel",     beats: [.quarter,.eighth,.eighth,.half,.quarter], bpm: 90),
    ]
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
