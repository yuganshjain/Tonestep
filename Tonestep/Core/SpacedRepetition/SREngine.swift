import Foundation
import SwiftData

/// SM-2 spaced repetition engine. Each drill type gets its own SRItem.
/// Grade 0-5: 0-1 = fail, 2 = barely correct, 3 = correct, 4 = easy, 5 = very easy.
final class SREngine {
    static func grade(for item: SRItem, quality: Int) -> SRItem {
        // quality: 0-5 (0 = blackout, 5 = perfect)
        if quality < 3 {
            item.repetitions = 0
            item.intervalDays = 1
        } else {
            switch item.repetitions {
            case 0: item.intervalDays = 1
            case 1: item.intervalDays = 6
            default:
                let newInterval = Double(item.intervalDays) * item.easeFactor
                item.intervalDays = max(1, Int(newInterval))
            }
            item.repetitions += 1
        }
        let ef = item.easeFactor + (0.1 - Double(5 - quality) * (0.08 + Double(5 - quality) * 0.02))
        item.easeFactor = max(1.3, ef)
        item.nextReviewDate = Calendar.current.date(byAdding: .day, value: item.intervalDays, to: Date()) ?? Date()
        return item
    }

    /// Convert a 0-1 accuracy to SM-2 quality (0-5)
    static func quality(from accuracy: Double, responseTime: TimeInterval) -> Int {
        switch accuracy {
        case 1.0 where responseTime < 3: return 5
        case 1.0: return 4
        case 0.5...: return 3
        case 0.25...: return 2
        default: return 0
        }
    }
}

// MARK: - Daily Session Builder

final class DailySessionBuilder {
    /// Build a list of drill types to present today, weighted toward due SR items and weak spots.
    static func buildSession(
        srItems: [SRItem],
        recentResults: [DrillResult],
        targetCount: Int,
        isPro: Bool,
        availableModules: [TrainingModule]
    ) -> [DrillPlan] {
        var plans: [DrillPlan] = []

        // 1. Due SR items (pro only)
        if isPro {
            let dueItems = srItems.filter(\.isDue).prefix(targetCount / 2)
            plans += dueItems.map { DrillPlan(drillType: $0.drillType, source: .spacedRepetition) }
        }

        // 2. Weak spots from last 14 days
        let weakDrillTypes = weakSpots(from: recentResults, limit: targetCount / 3)
        plans += weakDrillTypes
            .filter { dt in !plans.contains(where: { $0.drillType == dt }) }
            .map { DrillPlan(drillType: $0, source: .weakSpot) }

        // 3. Fill remainder with random drills from available modules
        let remaining = targetCount - plans.count
        if remaining > 0 {
            let randomDrills = randomDrillTypes(from: availableModules, count: remaining)
                .filter { dt in !plans.contains(where: { $0.drillType == dt }) }
                .map { DrillPlan(drillType: $0, source: .random) }
            plans += randomDrills
        }

        return Array(plans.prefix(targetCount)).shuffled()
    }

    private static func weakSpots(from results: [DrillResult], limit: Int) -> [String] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let recent = results.filter { $0.timestamp > cutoff }
        var typeStats: [String: (correct: Int, total: Int)] = [:]
        for r in recent {
            var stat = typeStats[r.drillType] ?? (0, 0)
            stat.total += 1
            if r.wasCorrect { stat.correct += 1 }
            typeStats[r.drillType] = stat
        }
        let sorted = typeStats
            .filter { $0.value.total >= 3 }
            .sorted { Double($0.value.correct) / Double($0.value.total) < Double($1.value.correct) / Double($1.value.total) }
        return Array(sorted.prefix(limit).map(\.key))
    }

    private static func randomDrillTypes(from modules: [TrainingModule], count: Int) -> [String] {
        var types: [String] = []
        for _ in 0..<count {
            guard let module = modules.randomElement() else { continue }
            let type_ = randomDrillType(for: module)
            types.append(type_)
        }
        return types
    }

    private static func randomDrillType(for module: TrainingModule) -> String {
        switch module {
        case .intervalRecognition:
            let interval = Interval.allCases.filter { $0 != .unison }.randomElement()!
            let direction = IntervalDirection.allCases.randomElement()!
            return "interval_\(interval.name.lowercased().replacingOccurrences(of: " ", with: "_"))_\(direction.rawValue.lowercased())"
        case .chordRecognition:
            let chord = ChordQuality.allCases.filter { !$0.isProOnly }.randomElement()!
            return chord.drillType
        case .scaleRecognition:
            let scale = ScaleType.allCases.filter(\.freeForAll).randomElement()!
            return scale.drillType
        case .functionalEar:
            let degree = ScaleDegree.beginnerSet.randomElement()!
            return degree.drillType
        default:
            return "interval_major_third_ascending"
        }
    }
}

struct DrillPlan {
    let drillType: String
    let source: DrillSource

    enum DrillSource {
        case spacedRepetition, weakSpot, random
    }
}
