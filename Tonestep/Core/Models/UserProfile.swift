import Foundation
import Combine
import WidgetKit

enum Instrument: String, CaseIterable, Codable {
    case piano = "Piano"
    case guitar = "Guitar"
    case bass = "Bass"
    case violin = "Violin"
    case voice = "Voice"

    var systemImage: String {
        switch self {
        case .piano: return "pianokeys"
        case .guitar: return "guitars"
        case .bass: return "guitars"
        case .violin: return "music.quarternote.3"
        case .voice: return "mic.fill"
        }
    }
}

enum SolfegeStyle: String, CaseIterable, Codable {
    case doReMi = "Do-Re-Mi"
    case numbers = "1-2-3"
}

enum InputMethod: String, CaseIterable, Codable {
    case buttons = "Buttons"
    case piano = "Piano Keyboard"
    case fretboard = "Fretboard"
}

enum LearningGoal: String, CaseIterable, Codable {
    case transcribe = "Transcribe songs by ear"
    case improvise = "Improvise better"
    case studyExams = "Music school / exams"
    case produce = "Produce / compose"
    case exploring = "Just exploring"
}

enum SessionLength: Int, CaseIterable, Codable {
    case short = 5
    case medium = 8
    case long = 12

    var label: String {
        switch self {
        case .short: return "Short (~5 min)"
        case .medium: return "Medium (~8 min)"
        case .long: return "Long (~12 min)"
        }
    }
}

final class UserProfileStore: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "onboardingDone") }
    }
    @Published var instrument: Instrument {
        didSet { save(\UserProfileStore.instrument, key: "instrument") }
    }
    @Published var solfegeStyle: SolfegeStyle {
        didSet { save(\UserProfileStore.solfegeStyle, key: "solfegeStyle") }
    }
    @Published var inputMethod: InputMethod {
        didSet { save(\UserProfileStore.inputMethod, key: "inputMethod") }
    }
    @Published var learningGoal: LearningGoal {
        didSet { save(\UserProfileStore.learningGoal, key: "learningGoal") }
    }
    @Published var sessionLength: SessionLength {
        didSet { save(\UserProfileStore.sessionLength, key: "sessionLength") }
    }
    @Published var xp: Int {
        didSet { UserDefaults.standard.set(xp, forKey: "xp"); syncWidget() }
    }
    @Published var currentStreak: Int {
        didSet { UserDefaults.standard.set(currentStreak, forKey: "currentStreak"); syncWidget() }
    }
    @Published var longestStreak: Int {
        didSet { UserDefaults.standard.set(longestStreak, forKey: "longestStreak") }
    }
    @Published var streakFreezes: Int {
        didSet { UserDefaults.standard.set(streakFreezes, forKey: "streakFreezes") }
    }
    @Published var lastSessionDate: Date? {
        didSet { UserDefaults.standard.set(lastSessionDate, forKey: "lastSessionDate") }
    }
    @Published var isPro: Bool {
        didSet { UserDefaults.standard.set(isPro, forKey: "isPro") }
    }

    var level: Int { TonestepLevel.level(for: xp) }

    init() {
        let ud = UserDefaults.standard
        hasCompletedOnboarding = ud.bool(forKey: "onboardingDone")
        instrument = Instrument(rawValue: ud.string(forKey: "instrument") ?? "") ?? .piano
        solfegeStyle = SolfegeStyle(rawValue: ud.string(forKey: "solfegeStyle") ?? "") ?? .doReMi
        inputMethod = InputMethod(rawValue: ud.string(forKey: "inputMethod") ?? "") ?? .buttons
        learningGoal = LearningGoal(rawValue: ud.string(forKey: "learningGoal") ?? "") ?? .exploring
        sessionLength = SessionLength(rawValue: ud.integer(forKey: "sessionLength")) ?? .medium
        xp = ud.integer(forKey: "xp")
        currentStreak = ud.integer(forKey: "currentStreak")
        longestStreak = ud.integer(forKey: "longestStreak")
        streakFreezes = ud.integer(forKey: "streakFreezes")
        lastSessionDate = ud.object(forKey: "lastSessionDate") as? Date
        isPro = ud.bool(forKey: "isPro")
    }

    var xpMultiplier: Double {
        switch currentStreak {
        case 7...: return 2.0
        case 3...6: return 1.5
        default: return 1.0
        }
    }

    var multiplierLabel: String? {
        switch currentStreak {
        case 7...: return "2× XP"
        case 3...6: return "1.5× XP"
        default: return nil
        }
    }

    func addXP(_ base: Int) {
        xp += max(1, Int(Double(base) * xpMultiplier))
    }

    func completeSession() {
        let today = Calendar.current.startOfDay(for: Date())
        if let last = lastSessionDate {
            let lastDay = Calendar.current.startOfDay(for: last)
            let diff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 1 {
                currentStreak += 1
            } else if diff > 1 {
                if streakFreezes > 0 {
                    streakFreezes -= 1
                } else {
                    currentStreak = 1
                }
            }
        } else {
            currentStreak = 1
        }
        longestStreak = max(longestStreak, currentStreak)
        lastSessionDate = Date()
        addXP(50)
    }

    func syncWidget() {
        let suiteName = "group.com.yugansh.Tonestep"
        guard let ud = UserDefaults(suiteName: suiteName) else { return }
        let current = TonestepLevel.level(for: xp)
        let lo = TonestepLevel.thresholds[current].0
        let hi = TonestepLevel.nextThreshold(for: xp)
        let progress = hi > lo ? Double(xp - lo) / Double(hi - lo) : 1.0
        let todayDone: Bool = {
            guard let last = lastSessionDate else { return false }
            return Calendar.current.isDateInToday(last)
        }()
        ud.set(currentStreak, forKey: "widget_streak")
        ud.set(xp, forKey: "widget_xp")
        ud.set(TonestepLevel.title(for: xp), forKey: "widget_levelName")
        ud.set(progress, forKey: "widget_levelProgress")
        ud.set(todayDone, forKey: "widget_todayDone")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func save<T: Codable>(_ keyPath: KeyPath<UserProfileStore, T>, key: String) {
        if let data = try? JSONEncoder().encode(self[keyPath: keyPath]) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

// MARK: - Level System

enum TonestepLevel {
    static let thresholds: [(Int, String)] = [
        (0,    "Tone Seeker"),
        (200,  "Pitch Apprentice"),
        (500,  "Interval Hunter"),
        (900,  "Chord Finder"),
        (1400, "Scale Explorer"),
        (2000, "Harmony Scholar"),
        (2800, "Rhythm Keeper"),
        (3800, "Melody Chaser"),
        (5000, "Chord Scholar"),
        (6500, "Ear Craftsman"),
        (8500, "Tone Architect"),
        (11000,"Pitch Surgeon"),
        (14000,"Interval Master"),
        (17500,"Chord Sage"),
        (21500,"Scale Virtuoso"),
        (26000,"Harmony Expert"),
        (31000,"Melody Wizard"),
        (37000,"Absolute Listener"),
        (44000,"Harmony Master"),
        (52000,"Perfect Ear"),
    ]

    static func level(for xp: Int) -> Int {
        var level = 0
        for (i, threshold) in thresholds.enumerated() {
            if xp >= threshold.0 { level = i }
        }
        return level
    }

    static func title(for xp: Int) -> String {
        thresholds[level(for: xp)].1
    }

    static func nextThreshold(for xp: Int) -> Int {
        let current = level(for: xp)
        if current + 1 < thresholds.count { return thresholds[current + 1].0 }
        return thresholds.last!.0
    }
}
