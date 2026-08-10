import SwiftUI
import SwiftData

struct ProgressTabView: View {
    @Query(sort: \DrillResult.timestamp, order: .reverse) private var allResults: [DrillResult]
    @EnvironmentObject private var userProfile: UserProfileStore
    @StateObject private var achievementStore = AchievementStore()
    @StateObject private var gcManager = GameCenterManager.shared
    @State private var shareImage: UIImage?
    @State private var showShare = false
    @State private var showLeaderboard = false

    private var accuracyByModule: [(TrainingModule, Double)] {
        TrainingModule.allCases.compactMap { module in
            let results = allResults.filter { $0.module == module }
            guard results.count >= 3 else { return nil }
            let accuracy = Double(results.filter(\.wasCorrect).count) / Double(results.count)
            return (module, accuracy)
        }
    }

    private var last7DaysData: [(String, Double, Int)] {
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.dateFormat = "EEE"
        return (0..<7).reversed().map { daysAgo in
            let day = cal.date(byAdding: .day, value: -daysAgo, to: Date())!
            let dayResults = allResults.filter { cal.isDate($0.timestamp, inSameDayAs: day) }
            let acc = dayResults.isEmpty ? 0.0 : Double(dayResults.filter(\.wasCorrect).count) / Double(dayResults.count)
            return (fmt.string(from: day), acc, dayResults.count)
        }
    }

    private var weakModules: [(TrainingModule, Double, Int)] {
        var stats: [TrainingModule: (Int, Int)] = [:]
        for r in allResults {
            var s = stats[r.module] ?? (0, 0)
            s.0 += r.wasCorrect ? 1 : 0; s.1 += 1
            stats[r.module] = s
        }
        return stats
            .filter { $0.value.1 >= 5 }
            .map { ($0.key, Double($0.value.0) / Double($0.value.1), $0.value.1) }
            .sorted { $0.1 < $1.1 }
            .prefix(5).map { ($0.0, $0.1, $0.2) }
    }

    // Famous song references for interval types — contextual anchor to real music
    private static let intervalSongHints: [String: String] = [
        "minor_second": "Jaws Theme",
        "major_second": "Happy Birthday (first two notes)",
        "minor_third": "Smoke on the Water",
        "major_third": "When the Saints Go Marching In",
        "perfect_fourth": "Here Comes the Bride",
        "tritone": "The Simpsons Theme",
        "perfect_fifth": "Twinkle Twinkle (2nd note)",
        "minor_sixth": "The Entertainer (bridge)",
        "major_sixth": "My Bonnie Lies Over the Ocean",
        "minor_seventh": "Somewhere (West Side Story)",
        "major_seventh": "Take On Me (chorus)",
        "octave": "Somewhere Over the Rainbow",
    ]

    private var overallAccuracy: Double {
        guard !allResults.isEmpty else { return 0 }
        return Double(allResults.filter(\.wasCorrect).count) / Double(allResults.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    progressHeader
                    overallCard
                    accuracyChartCard
                    if !accuracyByModule.isEmpty { moduleCard }
                    streakCalendarSection
                    achievementsSection
                    if !weakModules.isEmpty { weakSpotsCard }
                }
                .padding()
                .padding(.bottom, 100)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appPurple)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appPurple, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
            .sheet(isPresented: $showLeaderboard) {
                GameCenterLeaderboardView(leaderboardID: GameCenterManager.speedRoundLeaderboard)
            }
            .sheet(isPresented: $showShare) {
                if let img = shareImage {
                    ImageShareSheet(image: img)
                }
            }
        }
        .background(Color.appPurple.ignoresSafeArea())
    }

    private var progressHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Progress")
                    .font(.title2).fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("Your ear training journey")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            HStack(spacing: 16) {
                if GameCenterManager.shared.isAuthenticated {
                    Button { showLeaderboard = true } label: {
                        Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                            .font(.title3)
                    }
                }
                Button { renderShareImage(); showShare = true } label: {
                    Image(systemName: "square.and.arrow.up").foregroundStyle(.white)
                        .font(.title3)
                }
            }
        }
        .padding(.top, 4)
    }

    private func renderShareImage() {
        let card = StatsShareCard(
            accuracy: overallAccuracy,
            totalDrills: allResults.count,
            streak: userProfile.currentStreak,
            level: userProfile.level + 1
        )
        let renderer = ImageRenderer(content: card.frame(width: 340))
        renderer.scale = UIScreen.main.scale
        shareImage = renderer.uiImage
    }

    // MARK: - 7-Day Chart Card

    private var accuracyChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Accuracy — Last 7 Days").font(.headline)
                .foregroundStyle(TrainingModule.pastelText)
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(last7DaysData, id: \.0) { label, acc, count in
                        VStack(spacing: 4) {
                            if count > 0 {
                                Text("\(Int(acc * 100))%")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(TrainingModule.pastelSubtext)
                            }
                            RoundedRectangle(cornerRadius: 5)
                                .fill(barColor(acc, count: count))
                                .frame(
                                    width: (geo.size.width - 36) / 7,
                                    height: max(4, (geo.size.height - 40) * (count == 0 ? 0.04 : acc))
                                )
                                .animation(.spring(response: 0.6), value: acc)
                            Text(label)
                                .font(.system(size: 9))
                                .foregroundStyle(TrainingModule.pastelSubtext)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 120)

            HStack(spacing: 14) {
                legendDot(Color.appPurple, "≥ 80%")
                legendDot(Color.orange, "60–79%")
                legendDot(Color.red, "< 60%")
                legendDot(Color(red: 0.88, green: 0.88, blue: 0.92), "No data")
            }
        }
        .padding()
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private func barColor(_ acc: Double, count: Int) -> Color {
        if count == 0 { return Color(red: 0.88, green: 0.88, blue: 0.92) }
        if acc >= 0.8 { return Color.appPurple }
        if acc >= 0.6 { return Color.orange }
        return Color.red
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.system(size: 9)).foregroundStyle(TrainingModule.pastelSubtext)
        }
    }

    // MARK: - Overall Card

    private var overallCard: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("\(Int(overallAccuracy * 100))%")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.appPurple)
                Text("Overall accuracy")
                    .font(.caption).foregroundStyle(TrainingModule.pastelSubtext)
            }
            Divider().frame(height: 60)
            VStack(spacing: 4) {
                Text("\(allResults.count)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(TrainingModule.pastelText)
                Text("Total drills")
                    .font(.caption).foregroundStyle(TrainingModule.pastelSubtext)
            }
        }
        .padding()
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private var moduleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Accuracy by Module").font(.headline)
                .foregroundStyle(TrainingModule.pastelText)
            ForEach(accuracyByModule, id: \.0) { module, accuracy in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(module.moduleEmoji).frame(width: 22)
                        Text(module.rawValue).font(.subheadline)
                            .foregroundStyle(TrainingModule.pastelText)
                        Spacer()
                        Text("\(Int(accuracy * 100))%")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(accuracy >= 0.8 ? .green : accuracy >= 0.6 ? .orange : .red)
                    }
                    SwiftUI.ProgressView(value: accuracy)
                        .tint(accuracy >= 0.8 ? Color.appPurple : accuracy >= 0.6 ? .orange : .red)
                }
            }
        }
        .padding()
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private var streakCalendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity — Last 12 Weeks").font(.headline)
                .foregroundStyle(TrainingModule.pastelText)
            StreakCalendarView(results: allResults)
        }
        .padding()
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                    .foregroundStyle(TrainingModule.pastelText)
                Spacer()
                let unlocked = achievementStore.achievements.filter(\.isUnlocked).count
                Text("\(unlocked)/\(achievementStore.achievements.count)")
                    .font(.caption).foregroundStyle(TrainingModule.pastelSubtext)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(achievementStore.achievements) { achievement in
                    AchievementBadge(achievement: achievement)
                }
            }
        }
        .padding()
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private var weakSpotsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Blind Spots").font(.headline)
                        .foregroundStyle(TrainingModule.pastelText)
                    Text("Modules to focus on next").font(.caption)
                        .foregroundStyle(TrainingModule.pastelSubtext)
                }
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }

            ForEach(weakModules, id: \.0) { module, accuracy, count in
                NavigationLink(destination: moduleDestination(for: module)) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(module.pastelColor)
                                    .frame(width: 34, height: 34)
                                Text(module.moduleEmoji)
                                    .font(.system(size: 16))
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(module.rawValue).font(.subheadline)
                                    .foregroundStyle(TrainingModule.pastelText)
                                Text("\(count) drills · \(Int(accuracy * 100))% accuracy")
                                    .font(.caption2).foregroundStyle(TrainingModule.pastelSubtext)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(Int(accuracy * 100))%")
                                    .font(.subheadline).fontWeight(.bold)
                                    .foregroundStyle(accuracy < 0.5 ? .red : .orange)
                                Text("Train →")
                                    .font(.caption2).foregroundStyle(Color.appPurple)
                            }
                        }

                        SwiftUI.ProgressView(value: accuracy)
                            .tint(accuracy < 0.5 ? .red : .orange)

                        if let hint = songHint(for: module) {
                            HStack(spacing: 4) {
                                Image(systemName: "music.note").font(.system(size: 9))
                                    .foregroundStyle(Color.appPurple)
                                Text("Hear it in: \(hint)")
                                    .font(.caption2).foregroundStyle(Color.appPurple)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(red: 0.97, green: 0.97, blue: 1.0), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
    }

    private func songHint(for module: TrainingModule) -> String? {
        guard module == .intervalRecognition else { return nil }
        let weakIntervalTypes = allResults
            .filter { $0.module == .intervalRecognition }
            .reduce(into: [String: (Int, Int)]()) { acc, r in
                var s = acc[r.drillType] ?? (0, 0)
                s.0 += r.wasCorrect ? 1 : 0; s.1 += 1
                acc[r.drillType] = s
            }
            .filter { $0.value.1 >= 3 }
            .sorted { Double($0.value.0) / Double($0.value.1) < Double($1.value.0) / Double($1.value.1) }
            .first?.key ?? ""

        for (key, hint) in ProgressTabView.intervalSongHints {
            if weakIntervalTypes.contains(key) { return hint }
        }
        return nil
    }

    @ViewBuilder
    private func moduleDestination(for module: TrainingModule) -> some View {
        switch module {
        case .intervalRecognition: IntervalModuleView()
        case .chordRecognition:    ChordModuleView()
        case .scaleRecognition:    ScaleModuleView()
        case .functionalEar:       FunctionalEarModuleView()
        case .melodicDictation:    MelodyDictationView()
        case .rhythmTrainer:       RhythmTrainerModuleView()
        case .chordProgressions:   ChordProgressionModuleView()
        case .singingPractice:     SingingPracticeModuleView()
        case .noteIdentification:  NoteIdentificationModuleView()
        case .chordInversions:     ChordInversionsModuleView()
        case .intervalComparison:  IntervalComparisonModuleView()
        case .errorDetection:      ErrorDetectionModuleView()
        case .relativePitch:       RelativePitchModuleView()
        case .absolutePitch:       AbsolutePitchModuleView()
        case .jazzChords:          JazzChordsModuleView()
        }
    }
}

// MARK: - Achievement Badge

struct AchievementBadge: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? Color.appPurple.opacity(0.12) : Color(red: 0.9, green: 0.9, blue: 0.95))
                    .frame(width: 52, height: 52)
                Text(achievement.isUnlocked ? achievement.icon : "🔒")
                    .font(.system(size: 26))
                    .opacity(achievement.isUnlocked ? 1 : 0.4)
            }
            Text(achievement.title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(achievement.isUnlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .opacity(achievement.isUnlocked ? 1.0 : 0.5)
    }
}

// MARK: - Stats Share Card

struct StatsShareCard: View {
    let accuracy: Double
    let totalDrills: Int
    let streak: Int
    let level: Int

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "ear.fill").font(.title2).foregroundStyle(.purple)
                Text("EarIQ").font(.title2).fontWeight(.black)
                Spacer()
            }
            HStack(spacing: 20) {
                statBlock("\(Int(accuracy * 100))%", "Accuracy")
                statBlock("\(totalDrills)", "Drills")
                statBlock("\(streak)🔥", "Streak")
                statBlock("Lv \(level)", "Level")
            }
            Text("Training my ears with EarIQ")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 8)
    }

    private func statBlock(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(.purple)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Image Share Sheet

struct ImageShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Streak Calendar

struct StreakCalendarView: View {
    let results: [DrillResult]
    private let columns = Array(repeating: GridItem(.fixed(14), spacing: 4), count: 7)
    private let weeks = 12

    private var activeDays: Set<String> {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return Set(results.map { fmt.string(from: $0.timestamp) })
    }

    private func days() -> [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<(weeks * 7)).compactMap {
            Calendar.current.date(byAdding: .day, value: -(weeks * 7 - 1 - $0), to: today)
        }
    }

    var body: some View {
        let fmt = DateFormatter()
        let _ = { fmt.dateFormat = "yyyy-MM-dd" }()
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(days(), id: \.self) { day in
                RoundedRectangle(cornerRadius: 3)
                    .fill(activeDays.contains(fmt.string(from: day)) ? Color.appPurple : Color(red: 0.88, green: 0.88, blue: 0.92))
                    .frame(width: 14, height: 14)
            }
        }
    }
}
