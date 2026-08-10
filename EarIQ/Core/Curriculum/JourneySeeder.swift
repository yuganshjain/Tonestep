import Foundation

/// Places an existing user at a sensible point in the curriculum, so shipping
/// the journey does not look like their progress was wiped.
enum JourneySeeder {

    /// A chapter counts as already mastered at this volume and accuracy.
    private static let minResults = 10
    private static let minAccuracy = 0.8

    static func inferStartingStage(from results: [DrillResult], entitlement: Entitlement) -> Stage {
        let chapters = CurriculumBuilder.chapters(for: entitlement)
        let stages = CurriculumBuilder.stages(for: entitlement)

        // stages(for:) is never empty: chapters(for: .free) always yields 7 chapters.
        guard let firstStage = stages.first, let lastStage = stages.last else {
            fatalError("Curriculum is empty — CurriculumBuilder.allChapters must not be empty")
        }
        guard !results.isEmpty else { return firstStage }

        for chapter in chapters {
            // Every module in the chapter must be mastered independently. Pooling
            // them would let strong interval history skip a chapter that also
            // covers chords the user has never attempted.
            let mastered = chapter.modules.allSatisfy { module in
                let relevant = results.filter { $0.module == module }
                guard relevant.count >= minResults else { return false }
                let accuracy = Double(relevant.filter(\.wasCorrect).count) / Double(relevant.count)
                return accuracy >= minAccuracy
            }
            if mastered { continue }

            return stages.first { $0.chapterId == chapter.id } ?? firstStage
        }

        return lastStage
    }
}
