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

    private var weakSpots: [(String, Double)] {
        var stats: [String: (Int, Int)] = [:]
        for r in allResults {
            var s = stats[r.drillType] ?? (0, 0)
            s.0 += r.wasCorrect ? 1 : 0; s.1 += 1
            stats[r.drillType] = s
        }
        return stats
            .filter { $0.value.1 >= 5 }
            .map { ($0.key, Double($0.value.0) / Double($0.value.1)) }
            .sorted { $0.1 < $1.1 }
            .prefix(5).map { ($0.0, $0.1) }
    }

    private var overallAccuracy: Double {
        guard !allResults.isEmpty else { return 0 }
        return Double(allResults.filter(\.wasCorrect).count) / Double(allResults.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    overallCard
                    accuracyChartCard
                    if !accuracyByModule.isEmpty { moduleCard }
                    streakCalendarSection
                    achievementsSection
                    if !weakSpots.isEmpty { weakSpotsCard }
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        if GameCenterManager.shared.isAuthenticated {
                            Button { showLeaderboard = true } label: {
                                Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                            }
                        }
                        Button { renderShareImage(); showShare = true } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .sheet(isPresented: $showLeaderboard) {
                GameCenterLeaderboardView(leaderboardID: GameCenterManager.speedRoundLeaderboard)
            }
            .sheet(isPresented: $showShare) {
                if let img = shareImage {
                    ImageShareSheet(image: img)
                }
            }
        }
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
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(last7DaysData, id: \.0) { label, acc, count in
                        VStack(spacing: 4) {
                            if count > 0 {
                                Text("\(Int(acc * 100))%")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(.secondary)
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
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 120)

            HStack(spacing: 14) {
                legendDot(Color.purple, "≥ 80%")
                legendDot(Color.orange, "60–79%")
                legendDot(Color.red, "< 60%")
                legendDot(Color(.systemFill), "No data")
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func barColor(_ acc: Double, count: Int) -> Color {
        if count == 0 { return Color(.systemFill) }
        if acc >= 0.8 { return Color.purple }
        if acc >= 0.6 { return Color.orange }
        return Color.red
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    // MARK: - Overall Card

    private var overallCard: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("\(Int(overallAccuracy * 100))%")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.purple)
                Text("Overall accuracy")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider().frame(height: 60)
            VStack(spacing: 4) {
                Text("\(allResults.count)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("Total drills")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var moduleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Accuracy by Module").font(.headline)
            ForEach(accuracyByModule, id: \.0) { module, accuracy in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: module.systemImage)
                            .foregroundStyle(Color.purple).frame(width: 20)
                        Text(module.rawValue).font(.subheadline)
                        Spacer()
                        Text("\(Int(accuracy * 100))%")
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(accuracy >= 0.8 ? .green : accuracy >= 0.6 ? .orange : .red)
                    }
                    SwiftUI.ProgressView(value: accuracy)
                        .tint(accuracy >= 0.8 ? .green : accuracy >= 0.6 ? .orange : .red)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var streakCalendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity — Last 12 Weeks").font(.headline)
            StreakCalendarView(results: allResults)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.headline)
                Spacer()
                let unlocked = achievementStore.achievements.filter(\.isUnlocked).count
                Text("\(unlocked)/\(achievementStore.achievements.count)")
                    .font(.caption).foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(achievementStore.achievements) { achievement in
                    AchievementBadge(achievement: achievement)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var weakSpotsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your 5 Weakest Areas").font(.headline)
            ForEach(weakSpots, id: \.0) { drillType, accuracy in
                HStack {
                    Circle().fill(accuracy < 0.5 ? Color.red : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(drillType.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(accuracy * 100))%")
                        .fontWeight(.semibold)
                        .foregroundStyle(accuracy < 0.5 ? .red : .orange)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Achievement Badge

struct AchievementBadge: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(achievement.isUnlocked ? Color.purple.opacity(0.15) : Color(.systemFill))
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
                    .fill(activeDays.contains(fmt.string(from: day)) ? Color.purple : Color(.systemFill))
                    .frame(width: 14, height: 14)
            }
        }
    }
}
