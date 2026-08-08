import Foundation

struct Achievement: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let xpReward: Int
    var isUnlocked: Bool = false
    var unlockedAt: Date?

    static let catalog: [Achievement] = [
        Achievement(id: "first_drill",    title: "First Note",       description: "Complete your first drill",          icon: "🎵", xpReward: 50),
        Achievement(id: "streak_3",       title: "On a Roll",        description: "Reach a 3-day streak",               icon: "🔥", xpReward: 75),
        Achievement(id: "streak_7",       title: "Week Warrior",     description: "Keep a 7-day streak",                icon: "⚡", xpReward: 150),
        Achievement(id: "streak_30",      title: "Month Master",     description: "Keep a 30-day streak",               icon: "🏆", xpReward: 500),
        Achievement(id: "drills_50",      title: "Warming Up",       description: "Complete 50 drills",                 icon: "🎯", xpReward: 100),
        Achievement(id: "drills_100",     title: "Centurion",        description: "Complete 100 drills",                icon: "💯", xpReward: 200),
        Achievement(id: "drills_500",     title: "Dedicated Ear",    description: "Complete 500 drills",                icon: "👂", xpReward: 400),
        Achievement(id: "drills_1000",    title: "Ear Obsessed",     description: "Complete 1000 drills",               icon: "🧠", xpReward: 750),
        Achievement(id: "perfect_run",    title: "Perfect Run",      description: "10 correct answers in a row",        icon: "⭐", xpReward: 200),
        Achievement(id: "level_5",        title: "Ear Apprentice",   description: "Reach Level 5",                      icon: "🎓", xpReward: 150),
        Achievement(id: "level_10",       title: "Ear Expert",       description: "Reach Level 10",                     icon: "🎯", xpReward: 300),
        Achievement(id: "level_15",       title: "Ear Master",       description: "Reach Level 15",                     icon: "👑", xpReward: 500),
        Achievement(id: "all_free",       title: "Explorer",         description: "Try all free training modules",      icon: "🗺️", xpReward: 200),
        Achievement(id: "interval_ace",   title: "Interval Ace",     description: "80%+ on 20 interval drills",         icon: "↗️", xpReward: 150),
        Achievement(id: "chord_ace",      title: "Chord Crusher",    description: "80%+ on 20 chord drills",            icon: "🎸", xpReward: 150),
        Achievement(id: "melody_master",  title: "Melody Master",    description: "Complete 10 melody dictation drills", icon: "🎹", xpReward: 200),
        Achievement(id: "rhythm_keeper",  title: "Rhythm Keeper",    description: "Complete 10 rhythm drills",          icon: "🥁", xpReward: 150),
        Achievement(id: "theory_learner", title: "Theory Learner",   description: "Complete 5 theory lessons",          icon: "📚", xpReward: 200),
    ]
}

final class AchievementStore: ObservableObject {
    @Published private(set) var achievements: [Achievement]
    @Published var recentlyUnlocked: Achievement?

    private let storageKey = "eariq_achievements_v1"
    private var consecutiveCorrect = 0

    init() {
        if let data = UserDefaults.standard.data(forKey: "eariq_achievements_v1"),
           let saved = try? JSONDecoder().decode([Achievement].self, from: data) {
            let map = Dictionary(uniqueKeysWithValues: saved.map { ($0.id, $0) })
            achievements = Achievement.catalog.map { template in
                var a = template
                if let s = map[template.id] { a.isUnlocked = s.isUnlocked; a.unlockedAt = s.unlockedAt }
                return a
            }
        } else {
            achievements = Achievement.catalog
        }
    }

    func recordDrillResult(
        wasCorrect: Bool,
        totalDrills: Int,
        streak: Int,
        level: Int,
        modulesTried: Set<String>,
        intervalAccuracy: Double,
        chordAccuracy: Double,
        melodyDrills: Int,
        rhythmDrills: Int,
        lessonsCompleted: Int
    ) {
        consecutiveCorrect = wasCorrect ? consecutiveCorrect + 1 : 0

        let checks: [(String, Bool)] = [
            ("first_drill",    totalDrills >= 1),
            ("streak_3",       streak >= 3),
            ("streak_7",       streak >= 7),
            ("streak_30",      streak >= 30),
            ("drills_50",      totalDrills >= 50),
            ("drills_100",     totalDrills >= 100),
            ("drills_500",     totalDrills >= 500),
            ("drills_1000",    totalDrills >= 1000),
            ("perfect_run",    consecutiveCorrect >= 10),
            ("level_5",        level >= 4),
            ("level_10",       level >= 9),
            ("level_15",       level >= 14),
            ("all_free",       Set(["Interval Recognition","Chord Recognition","Scale Recognition","Functional Ear"]).isSubset(of: modulesTried)),
            ("interval_ace",   intervalAccuracy >= 0.8),
            ("chord_ace",      chordAccuracy >= 0.8),
            ("melody_master",  melodyDrills >= 10),
            ("rhythm_keeper",  rhythmDrills >= 10),
            ("theory_learner", lessonsCompleted >= 5),
        ]

        for (id, condition) in checks {
            if condition, let idx = achievements.firstIndex(where: { $0.id == id }), !achievements[idx].isUnlocked {
                achievements[idx].isUnlocked = true
                achievements[idx].unlockedAt = Date()
                recentlyUnlocked = achievements[idx]
            }
        }
        save()
    }

    func markLessonsCompleted(_ count: Int, streak: Int, level: Int, totalDrills: Int) {
        recordDrillResult(wasCorrect: true, totalDrills: totalDrills, streak: streak, level: level,
                          modulesTried: [], intervalAccuracy: 0, chordAccuracy: 0,
                          melodyDrills: 0, rhythmDrills: 0, lessonsCompleted: count)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
