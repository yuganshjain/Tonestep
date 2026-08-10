import Foundation

/// One fully resolved question. Sampled from a stage's DifficultyParams by
/// CurriculumBuilder, then rendered by a drill view.
struct DrillSpec: Equatable {
    let module: TrainingModule
    let item: ContentItem
    let voicing: VoicingMode
    let rootMidi: UInt8
    let choices: [ContentItem]
    let harmonicContext: HarmonicContext
    let replaysAllowed: Int?
    let responseDeadline: TimeInterval?

    /// Join key for DrillResult and SRItem. Intervals carry direction, matching
    /// the legacy format; everything else does not.
    var drillType: String {
        switch item {
        case .interval:
            return "\(item.drillType)_\(voicing.legacySuffix)"
        case .chord, .scale, .degree, .progression:
            return item.drillType
        }
    }

    var correctChoiceIndex: Int? {
        choices.firstIndex(of: item)
    }
}
