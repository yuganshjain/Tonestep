import XCTest
@testable import Tonestep

/// Validates that what the app *plays* matches what it *claims*.
///
/// The rest of the suite checks plumbing. This checks the music: if an exercise
/// says "Perfect 5th" the sounded pitches must actually be seven semitones
/// apart, and if it says "Dorian" the scale must have a minor third and a major
/// sixth. A wrong constant here teaches users the wrong thing, silently.
final class MusicalCorrectnessTests: XCTestCase {

    // MARK: - Intervals

    /// Semitone counts, from the definition of each interval.
    func test_every_interval_has_the_correct_semitone_count() {
        let expected: [Interval: Int] = [
            .unison: 0, .minorSecond: 1, .majorSecond: 2, .minorThird: 3,
            .majorThird: 4, .perfectFourth: 5, .tritone: 6, .perfectFifth: 7,
            .minorSixth: 8, .majorSixth: 9, .minorSeventh: 10,
            .majorSeventh: 11, .octave: 12
        ]
        for (interval, semitones) in expected {
            XCTAssertEqual(interval.rawValue, semitones,
                           "\(interval.name) should span \(semitones) semitones")
        }
    }

    /// A fifth above C4 must be G4, not something else.
    func test_interval_produces_the_right_pitch_above_middle_c() {
        let c4: UInt8 = 60
        XCTAssertEqual(Int(c4) + Interval.perfectFifth.rawValue, 67)  // G4
        XCTAssertEqual(Int(c4) + Interval.majorThird.rawValue, 64)    // E4
        XCTAssertEqual(Int(c4) + Interval.octave.rawValue, 72)        // C5
    }

    /// Frequency ratios are the ground truth for interval size.
    func test_perfect_fifth_frequency_ratio_is_three_halves() {
        let root = ToneRenderer.frequency(forMidiNote: 60)
        let fifth = ToneRenderer.frequency(forMidiNote: 67)
        // Equal temperament approximates 3:2 (1.5) as 1.4983.
        XCTAssertEqual(Double(fifth / root), 1.4983, accuracy: 0.001)
    }

    func test_octave_frequency_ratio_is_exactly_two() {
        let root = ToneRenderer.frequency(forMidiNote: 60)
        let octave = ToneRenderer.frequency(forMidiNote: 72)
        XCTAssertEqual(Double(octave / root), 2.0, accuracy: 0.0001)
    }

    // MARK: - Chords

    func test_triads_are_built_correctly() {
        XCTAssertEqual(ChordQuality.major.semitones, [0, 4, 7],
                       "major = root, major 3rd, perfect 5th")
        XCTAssertEqual(ChordQuality.minor.semitones, [0, 3, 7],
                       "minor = root, minor 3rd, perfect 5th")
        XCTAssertEqual(ChordQuality.diminished.semitones, [0, 3, 6],
                       "diminished = minor 3rd, diminished 5th")
        XCTAssertEqual(ChordQuality.augmented.semitones, [0, 4, 8],
                       "augmented = major 3rd, augmented 5th")
    }

    func test_seventh_chords_are_built_correctly() {
        XCTAssertEqual(ChordQuality.dominantSeventh.semitones, [0, 4, 7, 10],
                       "dominant 7th = major triad + minor 7th")
        XCTAssertEqual(ChordQuality.majorSeventh.semitones, [0, 4, 7, 11],
                       "major 7th = major triad + major 7th")
        XCTAssertEqual(ChordQuality.minorSeventh.semitones, [0, 3, 7, 10],
                       "minor 7th = minor triad + minor 7th")
    }

    func test_suspended_chords_have_no_third() {
        for quality in [ChordQuality.suspendedSecond, .suspendedFourth] {
            XCTAssertFalse(quality.semitones.contains(3), "\(quality.rawValue) has a minor 3rd")
            XCTAssertFalse(quality.semitones.contains(4), "\(quality.rawValue) has a major 3rd")
        }
        XCTAssertEqual(ChordQuality.suspendedSecond.semitones, [0, 2, 7])
        XCTAssertEqual(ChordQuality.suspendedFourth.semitones, [0, 5, 7])
    }

    /// Every chord must start on its root and rise.
    func test_all_chords_start_at_the_root_and_ascend() {
        for quality in ChordQuality.allCases {
            XCTAssertEqual(quality.semitones.first, 0, "\(quality.rawValue) does not start on the root")
            XCTAssertEqual(quality.semitones, quality.semitones.sorted(),
                           "\(quality.rawValue) is not in ascending order")
        }
    }

    // MARK: - Scales

    func test_major_scale_is_the_correct_step_pattern() {
        // Tone, tone, semitone, tone, tone, tone, semitone.
        XCTAssertEqual(ScaleType.major.semitones, [0, 2, 4, 5, 7, 9, 11, 12])
    }

    func test_natural_minor_flattens_the_third_sixth_and_seventh() {
        XCTAssertEqual(ScaleType.naturalMinor.semitones, [0, 2, 3, 5, 7, 8, 10, 12])
    }

    func test_harmonic_minor_raises_only_the_seventh() {
        let natural = ScaleType.naturalMinor.semitones
        let harmonic = ScaleType.harmonicMinor.semitones
        XCTAssertEqual(harmonic[6], natural[6] + 1, "the 7th should be raised")
        XCTAssertEqual(Array(harmonic[0..<6]), Array(natural[0..<6]),
                       "nothing below the 7th should change")
    }

    func test_modes_have_their_defining_intervals() {
        // Dorian: minor 3rd but major 6th — that 6th is what distinguishes it.
        XCTAssertTrue(ScaleType.dorian.semitones.contains(3), "dorian needs a minor 3rd")
        XCTAssertTrue(ScaleType.dorian.semitones.contains(9), "dorian needs a major 6th")
        // Lydian: raised 4th.
        XCTAssertTrue(ScaleType.lydian.semitones.contains(6), "lydian needs a #4")
        // Mixolydian: major 3rd, flat 7th.
        XCTAssertTrue(ScaleType.mixolydian.semitones.contains(4))
        XCTAssertTrue(ScaleType.mixolydian.semitones.contains(10))
        // Phrygian: flat 2nd.
        XCTAssertTrue(ScaleType.phrygian.semitones.contains(1), "phrygian needs a b2")
        // Locrian: diminished 5th.
        XCTAssertTrue(ScaleType.locrian.semitones.contains(6), "locrian needs a b5")
    }

    func test_pentatonics_have_five_distinct_notes() {
        for scale in [ScaleType.majorPentatonic, .minorPentatonic] {
            let withoutOctave = scale.semitones.filter { $0 != 12 }
            XCTAssertEqual(withoutOctave.count, 5, "\(scale.rawValue) is not pentatonic")
        }
    }

    func test_blues_scale_contains_the_blue_note() {
        XCTAssertEqual(ScaleType.blues.semitones, [0, 3, 5, 6, 7, 10, 12],
                       "blues = minor pentatonic plus the b5")
    }

    func test_all_scales_start_at_the_root_and_ascend() {
        for scale in ScaleType.allCases {
            XCTAssertEqual(scale.semitones.first, 0, "\(scale.rawValue) does not start on the root")
            XCTAssertEqual(scale.semitones, scale.semitones.sorted(),
                           "\(scale.rawValue) is not ascending")
            XCTAssertEqual(scale.semitones.last, 12, "\(scale.rawValue) should end on the octave")
        }
    }

    // MARK: - Scale degrees (functional ear)

    func test_scale_degrees_match_the_major_scale() {
        XCTAssertEqual(ScaleDegree.do_.semitoneFromRoot, 0)
        XCTAssertEqual(ScaleDegree.re.semitoneFromRoot, 2)
        XCTAssertEqual(ScaleDegree.mi.semitoneFromRoot, 4)
        XCTAssertEqual(ScaleDegree.fa.semitoneFromRoot, 5)
        XCTAssertEqual(ScaleDegree.sol.semitoneFromRoot, 7)
        XCTAssertEqual(ScaleDegree.la.semitoneFromRoot, 9)
        XCTAssertEqual(ScaleDegree.ti.semitoneFromRoot, 11)
    }

    /// The degrees the app teaches must be exactly the major scale it plays.
    func test_degrees_agree_with_the_major_scale_definition() {
        let fromDegrees = ScaleDegree.allCases.map(\.semitoneFromRoot)
        let fromScale = Array(ScaleType.major.semitones.dropLast())  // drop the octave
        XCTAssertEqual(fromDegrees, fromScale)
    }

    // MARK: - Chord progressions

    func test_progression_roots_match_their_roman_numerals() {
        // Scale degree -> semitones above the tonic in a major key.
        let degreeSemitones = ["I": 0, "i": 0, "ii": 2, "III": 4, "IV": 5,
                               "V": 7, "vi": 9, "VI": 8, "VII": 10]
        for progression in ChordProgression.all {
            for (numeral, offset) in zip(progression.romanNumerals, progression.rootOffsets) {
                guard let expected = degreeSemitones[numeral] else {
                    XCTFail("unmapped numeral \(numeral) in \(progression.name)")
                    continue
                }
                XCTAssertEqual(offset, expected,
                               "\(progression.name): \(numeral) should be \(expected) semitones up")
            }
        }
    }

    /// Lowercase numerals are minor chords, uppercase are major.
    func test_progression_qualities_match_numeral_case() {
        for progression in ChordProgression.all {
            for (numeral, quality) in zip(progression.romanNumerals, progression.qualities) {
                let isLowercase = numeral.first?.isLowercase ?? false
                if isLowercase {
                    XCTAssertEqual(quality, .minor,
                                   "\(progression.name): \(numeral) is lowercase so should be minor")
                } else {
                    XCTAssertEqual(quality, .major,
                                   "\(progression.name): \(numeral) is uppercase so should be major")
                }
            }
        }
    }

    func test_every_progression_is_internally_consistent() {
        for progression in ChordProgression.all {
            XCTAssertEqual(progression.romanNumerals.count, progression.rootOffsets.count,
                           "\(progression.name) numeral/offset count mismatch")
            XCTAssertEqual(progression.romanNumerals.count, progression.qualities.count,
                           "\(progression.name) numeral/quality count mismatch")
        }
    }

    // MARK: - Play-Along content

    /// The bundled melodies must be the tunes they claim to be.
    func test_ode_to_joy_opens_with_its_actual_melody() throws {
        let piece = try XCTUnwrap(LessonLibrary.piece(id: "ode_to_joy"))
        // E E F G G F E D — the opening phrase, in C.
        let opening = piece.notes.prefix(8).map(\.midiNote)
        XCTAssertEqual(opening, [64, 64, 65, 67, 67, 65, 64, 62])
    }

    func test_twinkle_opens_with_its_actual_melody() throws {
        let piece = try XCTUnwrap(LessonLibrary.piece(id: "twinkle"))
        // C C G G A A G — the opening phrase.
        let opening = piece.notes.prefix(7).map(\.midiNote)
        XCTAssertEqual(opening, [60, 60, 67, 67, 69, 69, 67])
    }

    func test_mary_had_a_little_lamb_opens_with_its_actual_melody() throws {
        let piece = try XCTUnwrap(LessonLibrary.piece(id: "mary_had_a_little_lamb"))
        // E D C D E E E.
        let opening = piece.notes.prefix(7).map(\.midiNote)
        XCTAssertEqual(opening, [64, 62, 60, 62, 64, 64, 64])
    }

    func test_library_has_a_real_practice_catalogue() {
        XCTAssertGreaterThanOrEqual(LessonLibrary.all.count, 15,
                                    "three nursery rhymes is not a practice library")
    }

    /// Every difficulty tier must actually have pieces in it, or the grading
    /// is decorative.
    func test_every_difficulty_tier_is_populated() {
        for tier in 1...5 {
            let count = LessonLibrary.all.filter { $0.difficulty == tier }.count
            XCTAssertGreaterThan(count, 0, "no pieces at difficulty \(tier)")
        }
    }

    /// Harder tiers should demand a wider reach than easier ones.
    func test_harder_pieces_span_a_wider_range() {
        func averageSpan(_ tier: Int) -> Double {
            let spans = LessonLibrary.all
                .filter { $0.difficulty == tier }
                .compactMap { $0.range.map { Double($0.upperBound - $0.lowerBound) } }
            return spans.isEmpty ? 0 : spans.reduce(0, +) / Double(spans.count)
        }
        XCTAssertGreaterThan(averageSpan(4), averageSpan(1),
                             "advanced pieces should cover more ground than beginner ones")
    }

    func test_fur_elise_opens_with_its_actual_motif() throws {
        let piece = try XCTUnwrap(LessonLibrary.piece(id: "fur_elise"))
        // E D# E D# E B D C — the famous alternating semitone opening.
        XCTAssertEqual(piece.notes.prefix(8).map(\.midiNote),
                       [76, 75, 76, 75, 76, 71, 74, 72])
    }

    func test_hot_cross_buns_is_three_descending_steps() throws {
        let piece = try XCTUnwrap(LessonLibrary.piece(id: "hot_cross_buns"))
        XCTAssertEqual(piece.notes.prefix(3).map(\.midiNote), [64, 62, 60])
    }

    func test_mountain_king_climbs(){
        guard let piece = LessonLibrary.piece(id: "mountain_king") else { return XCTFail() }
        let first = piece.notes.prefix(5).map(\.midiNote)
        XCTAssertEqual(first, [69, 71, 72, 74, 76], "should climb the minor scale")
    }

    func test_composers_are_credited_where_known() {
        let beethoven = LessonLibrary.all.filter { $0.composer?.contains("Beethoven") == true }
        XCTAssertGreaterThanOrEqual(beethoven.count, 2, "Ode to Joy and Für Elise are both Beethoven")
    }

    func test_bundled_melodies_stay_in_a_singable_range() {
        for piece in LessonLibrary.all {
            for note in piece.notes {
                XCTAssertTrue((48...84).contains(note.midiNote),
                              "\(piece.title) has \(note.midiNote), outside C3-C6")
            }
        }
    }

    func test_bundled_melodies_have_no_overlapping_notes() {
        for piece in LessonLibrary.all {
            let sorted = piece.notes.sorted { $0.startBeat < $1.startBeat }
            for (a, b) in zip(sorted, sorted.dropFirst()) {
                XCTAssertLessThanOrEqual(a.startBeat + a.durationBeats, b.startBeat + 0.0001,
                                         "\(piece.title): notes overlap, these are monophonic tunes")
            }
        }
    }
}
