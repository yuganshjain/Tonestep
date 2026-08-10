import Foundation

/// Compact description of how a chapter's difficulty moves from start to end.
/// Every axis is non-decreasing, so generated stages are monotonic by construction.
struct DifficultyEnvelope {
    /// Nested, growing pools. Stage i selects the step at its progress fraction.
    let poolSteps: [[ContentItem]]
    let answerSetStart: Int
    let answerSetEnd: Int
    let contextStart: HarmonicContext
    let contextEnd: HarmonicContext
    let voicingStart: Set<VoicingMode>
    let voicingEnd: Set<VoicingMode>
    let registerStart: RegisterSpan
    let registerEnd: RegisterSpan
    let rootStart: RootPolicy
    let rootEnd: RootPolicy
    /// Applied only in the last 15% of the chapter.
    let replaysAtEnd: Int?
    let deadlineAtEnd: TimeInterval?

    /// Fractions at which each discrete axis switches from start to end.
    private static let voicingSwitch = 0.4
    private static let contextSwitch = 0.5
    private static let registerSwitch = 0.6
    private static let rootSwitch = 0.7
    private static let pressureSwitch = 0.85

    func params(atStage index: Int, of total: Int) -> DifficultyParams {
        let t = total <= 1 ? 1.0 : Double(index) / Double(total - 1)

        let poolIndex = min(Int(t * Double(poolSteps.count)), poolSteps.count - 1)
        let pool = poolSteps[max(0, poolIndex)]

        let rawAnswerSet = answerSetStart
            + Int((Double(answerSetEnd - answerSetStart) * t).rounded())
        let answerSet = max(2, min(rawAnswerSet, pool.count))

        return DifficultyParams(
            contentPool: pool,
            answerSetSize: answerSet,
            harmonicContext: t >= Self.contextSwitch ? contextEnd : contextStart,
            voicings: t >= Self.voicingSwitch ? voicingEnd : voicingStart,
            registerSpan: t >= Self.registerSwitch ? registerEnd : registerStart,
            rootPolicy: t >= Self.rootSwitch ? rootEnd : rootStart,
            replaysAllowed: t >= Self.pressureSwitch ? replaysAtEnd : nil,
            responseDeadline: t >= Self.pressureSwitch ? deadlineAtEnd : nil,
            timbre: .primary
        )
    }
}

struct Chapter: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let modules: [TrainingModule]
    let stageCount: Int
    let envelope: DifficultyEnvelope
    let isProOnly: Bool
}

struct PassCriteria: Equatable {
    let minQuestions: Int
    let minAccuracy: Double
    /// Ascending accuracy thresholds for 1, 2 and 3 stars.
    let starThresholds: [Double]

    static let standard = PassCriteria(
        minQuestions: 10,
        minAccuracy: 0.8,
        starThresholds: [0.8, 0.9, 1.0]
    )
}

struct Stage: Identifiable, Equatable {
    let chapterId: String
    /// 0-based. Any user-facing number is computed at render time.
    let indexInChapter: Int
    let params: DifficultyParams
    let passCriteria: PassCriteria

    /// Persistent identity. Deliberately not a global integer: Phase 2 inserts
    /// chapters mid-arc, which would renumber every later stage and corrupt
    /// saved progress.
    var id: String { "\(chapterId)-\(indexInChapter)" }
}
