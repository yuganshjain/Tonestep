import Foundation

/// The authored curriculum. Ten chapters, 102 stages, running
/// functional -> intervallic -> harmonic -> modal -> integrated.
enum CurriculumBuilder {

    // MARK: - Pools

    private static let perfectPool1: [ContentItem] = [.interval(.perfectFifth), .interval(.octave)]
    private static let perfectPool2: [ContentItem] = [.interval(.perfectFifth), .interval(.octave), .interval(.perfectFourth)]

    private static let thirdsPool: [ContentItem] = [.interval(.minorThird), .interval(.majorThird)]
    private static let thirdsAndTriads: [ContentItem] = [
        .interval(.minorThird), .interval(.majorThird), .chord(.major), .chord(.minor)
    ]

    private static let triads2: [ContentItem] = [.chord(.major), .chord(.minor)]
    private static let triads3: [ContentItem] = [.chord(.major), .chord(.minor), .chord(.diminished)]
    private static let triads4: [ContentItem] = [.chord(.major), .chord(.minor), .chord(.diminished), .chord(.augmented)]

    private static let smallIntervals: [ContentItem] = [
        .interval(.minorSecond), .interval(.majorSecond), .interval(.minorThird), .interval(.majorThird)
    ]
    private static let midIntervals: [ContentItem] = smallIntervals + [
        .interval(.perfectFourth), .interval(.tritone), .interval(.perfectFifth)
    ]
    private static let allIntervals: [ContentItem] = midIntervals + [
        .interval(.minorSixth), .interval(.majorSixth),
        .interval(.minorSeventh), .interval(.majorSeventh), .interval(.octave)
    ]

    private static let degrees3: [ContentItem] = [.degree(.do_), .degree(.sol), .degree(.mi)]
    private static let degrees5: [ContentItem] = degrees3 + [.degree(.la), .degree(.re)]
    private static let degrees7: [ContentItem] = degrees5 + [.degree(.fa), .degree(.ti)]

    private static let scales2: [ContentItem] = [.scale(.major), .scale(.naturalMinor)]
    private static let scales4: [ContentItem] = scales2 + [.scale(.majorPentatonic), .scale(.minorPentatonic)]

    private static let sevenths3: [ContentItem] = [
        .chord(.dominantSeventh), .chord(.majorSeventh), .chord(.minorSeventh)
    ]
    private static let sevenths5: [ContentItem] = sevenths3 + [.chord(.suspendedFourth), .chord(.suspendedSecond)]
    private static let sevenths6: [ContentItem] = sevenths5 + [.chord(.addedNinth)]

    private static let modes3: [ContentItem] = [.scale(.dorian), .scale(.lydian), .scale(.mixolydian)]
    private static let modes4: [ContentItem] = modes3 + [.scale(.phrygian)]
    private static let modes7: [ContentItem] = modes4 + [
        .scale(.locrian), .scale(.harmonicMinor), .scale(.melodicMinor)
    ]

    private static let freeFieldSmall: [ContentItem] = midIntervals + triads4 + degrees7
    private static let freeFieldFull: [ContentItem] = allIntervals + triads4 + sevenths3 + degrees7 + scales4

    // MARK: - Chapters

    static let allChapters: [Chapter] = [
        Chapter(
            id: "finding_home", title: "Finding Home",
            subtitle: "Hear the tonic, then Sol, then Mi",
            modules: [.functionalEar], stageCount: 8,
            envelope: DifficultyEnvelope(
                poolSteps: [[.degree(.do_), .degree(.sol)], degrees3],
                answerSetStart: 2, answerSetEnd: 3,
                contextStart: .cadencePrimer, contextEnd: .cadencePrimer,
                voicingStart: [.ascending], voicingEnd: [.ascending],
                registerStart: .fixedMiddle, registerEnd: .fixedMiddle,
                rootStart: .fixedC, rootEnd: .fixedC,
                replaysAtEnd: nil, deadlineAtEnd: nil
            ),
            isProOnly: false
        ),
        Chapter(
            id: "perfect_intervals", title: "The Perfect Intervals",
            subtitle: "Fifths, octaves and fourths",
            modules: [.intervalRecognition], stageCount: 8,
            envelope: DifficultyEnvelope(
                poolSteps: [perfectPool1, perfectPool2],
                answerSetStart: 2, answerSetEnd: 3,
                contextStart: .cadencePrimer, contextEnd: .droneRoot,
                voicingStart: [.ascending], voicingEnd: [.ascending, .descending],
                registerStart: .fixedMiddle, registerEnd: .twoOctaves,
                rootStart: .fixedC, rootEnd: .fixedC,
                replaysAtEnd: nil, deadlineAtEnd: nil
            ),
            isProOnly: false
        ),
        Chapter(
            id: "major_vs_minor", title: "Major vs Minor",
            subtitle: "The third is what carries the mood",
            modules: [.intervalRecognition, .chordRecognition], stageCount: 10,
            envelope: DifficultyEnvelope(
                poolSteps: [thirdsPool, thirdsAndTriads],
                answerSetStart: 2, answerSetEnd: 4,
                contextStart: .cadencePrimer, contextEnd: .droneRoot,
                voicingStart: [.ascending], voicingEnd: [.ascending, .harmonic],
                registerStart: .fixedMiddle, registerEnd: .twoOctaves,
                rootStart: .fixedC, rootEnd: .randomRoot,
                replaysAtEnd: nil, deadlineAtEnd: nil
            ),
            isProOnly: false
        ),
        Chapter(
            id: "triad_family", title: "The Triad Family",
            subtitle: "Add diminished and augmented",
            modules: [.chordRecognition], stageCount: 10,
            envelope: DifficultyEnvelope(
                poolSteps: [triads2, triads3, triads4],
                answerSetStart: 2, answerSetEnd: 4,
                contextStart: .cadencePrimer, contextEnd: .droneRoot,
                voicingStart: [.harmonic], voicingEnd: [.harmonic, .ascending],
                registerStart: .fixedMiddle, registerEnd: .twoOctaves,
                rootStart: .fixedC, rootEnd: .randomRoot,
                replaysAtEnd: nil, deadlineAtEnd: nil
            ),
            isProOnly: false
        ),
        Chapter(
            id: "steps_and_leaps", title: "Steps and Leaps",
            subtitle: "Every interval in the octave",
            modules: [.intervalRecognition], stageCount: 12,
            envelope: DifficultyEnvelope(
                poolSteps: [smallIntervals, midIntervals, allIntervals],
                answerSetStart: 4, answerSetEnd: 6,
                contextStart: .droneRoot, contextEnd: .isolated,
                voicingStart: [.ascending, .descending],
                voicingEnd: [.ascending, .descending, .harmonic],
                registerStart: .twoOctaves, registerEnd: .threeOctaves,
                rootStart: .fixedC, rootEnd: .randomRoot,
                replaysAtEnd: 2, deadlineAtEnd: nil
            ),
            isProOnly: false
        ),
        Chapter(
            id: "hearing_function", title: "Hearing Function, Not Distance",
            subtitle: "All seven degrees, losing the drone",
            modules: [.functionalEar], stageCount: 12,
            envelope: DifficultyEnvelope(
                poolSteps: [degrees3, degrees5, degrees7],
                answerSetStart: 3, answerSetEnd: 7,
                contextStart: .droneRoot, contextEnd: .isolated,
                voicingStart: [.ascending], voicingEnd: [.ascending],
                registerStart: .fixedMiddle, registerEnd: .twoOctaves,
                rootStart: .fixedC, rootEnd: .randomRoot,
                replaysAtEnd: 2, deadlineAtEnd: nil
            ),
            isProOnly: false
        ),
        Chapter(
            id: "scales_and_modes", title: "Scales and Modes",
            subtitle: "Major, minor and the pentatonics",
            modules: [.scaleRecognition], stageCount: 10,
            envelope: DifficultyEnvelope(
                poolSteps: [scales2, scales4],
                answerSetStart: 2, answerSetEnd: 4,
                contextStart: .cadencePrimer, contextEnd: .droneRoot,
                voicingStart: [.ascending], voicingEnd: [.ascending, .descending],
                registerStart: .fixedMiddle, registerEnd: .twoOctaves,
                rootStart: .fixedC, rootEnd: .randomRoot,
                replaysAtEnd: nil, deadlineAtEnd: nil
            ),
            isProOnly: false
        ),
        Chapter(
            id: "sevenths_and_colour", title: "Sevenths and Colour",
            subtitle: "Four-note chords and suspensions",
            modules: [.chordRecognition], stageCount: 10,
            envelope: DifficultyEnvelope(
                poolSteps: [sevenths3, sevenths5, sevenths6],
                answerSetStart: 3, answerSetEnd: 6,
                contextStart: .droneRoot, contextEnd: .isolated,
                voicingStart: [.harmonic], voicingEnd: [.harmonic, .ascending],
                registerStart: .twoOctaves, registerEnd: .threeOctaves,
                rootStart: .fixedC, rootEnd: .randomRoot,
                replaysAtEnd: 2, deadlineAtEnd: nil
            ),
            isProOnly: true
        ),
        Chapter(
            id: "modal_colours", title: "Modal Colours",
            subtitle: "Dorian through Locrian",
            modules: [.scaleRecognition], stageCount: 10,
            envelope: DifficultyEnvelope(
                poolSteps: [modes3, modes4, modes7],
                answerSetStart: 3, answerSetEnd: 6,
                contextStart: .droneRoot, contextEnd: .isolated,
                voicingStart: [.ascending], voicingEnd: [.ascending, .descending],
                registerStart: .twoOctaves, registerEnd: .threeOctaves,
                rootStart: .fixedC, rootEnd: .randomRoot,
                replaysAtEnd: 2, deadlineAtEnd: nil
            ),
            isProOnly: true
        ),
        Chapter(
            id: "free_field", title: "Free Field",
            subtitle: "No context, random roots, against the clock",
            modules: [.intervalRecognition, .chordRecognition, .scaleRecognition, .functionalEar],
            stageCount: 12,
            envelope: DifficultyEnvelope(
                poolSteps: [freeFieldSmall, freeFieldFull],
                answerSetStart: 4, answerSetEnd: 8,
                contextStart: .isolated, contextEnd: .isolated,
                voicingStart: [.ascending, .descending],
                voicingEnd: [.ascending, .descending, .harmonic],
                registerStart: .twoOctaves, registerEnd: .threeOctaves,
                rootStart: .randomRoot, rootEnd: .randomRoot,
                replaysAtEnd: 0, deadlineAtEnd: 8
            ),
            isProOnly: true
        )
    ]

    // MARK: - Access

    static func chapters(for entitlement: Entitlement) -> [Chapter] {
        switch entitlement {
        case .pro:  return allChapters
        case .free: return allChapters.filter { !$0.isProOnly }
        }
    }

    static func stages(for entitlement: Entitlement) -> [Stage] {
        chapters(for: entitlement).flatMap { chapter in
            (0..<chapter.stageCount).map { index in
                Stage(
                    chapterId: chapter.id,
                    indexInChapter: index,
                    params: chapter.envelope.params(atStage: index, of: chapter.stageCount),
                    passCriteria: .standard
                )
            }
        }
    }

    static func stage(id: String, entitlement: Entitlement) -> Stage? {
        stages(for: entitlement).first { $0.id == id }
    }

    /// Samples `count` resolved drills from a stage. Deterministic: the same
    /// stage always yields the same drills, in the same order.
    static func drillSpecs(for stage: Stage, count: Int) -> [DrillSpec] {
        guard count > 0 else { return [] }
        let params = stage.params
        guard !params.contentPool.isEmpty else { return [] }

        // Sorted, because Set iteration order is not stable across runs.
        let voicings = params.voicings.sorted()
        guard !voicings.isEmpty else { return [] }

        var rng = SeededGenerator(seed: SeededGenerator.seed(from: stage.id))
        var specs: [DrillSpec] = []

        for _ in 0..<count {
            let item = params.contentPool.randomElement(using: &rng)!
            let voicing = voicings.randomElement(using: &rng)!

            let root: UInt8
            switch params.rootPolicy {
            case .fixedC:
                root = 60
            case .randomRoot:
                root = UInt8.random(in: params.registerSpan.midiRange, using: &rng)
            }

            let distractors = params.contentPool
                .filter { $0 != item }
                .shuffled(using: &rng)
                .prefix(max(0, params.answerSetSize - 1))
            let choices = ([item] + distractors).shuffled(using: &rng)

            specs.append(DrillSpec(
                module: item.module,
                item: item,
                voicing: voicing,
                rootMidi: root,
                choices: choices,
                harmonicContext: params.harmonicContext,
                replaysAllowed: params.replaysAllowed,
                responseDeadline: params.responseDeadline
            ))
        }
        return specs
    }
}
