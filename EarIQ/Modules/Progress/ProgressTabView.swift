import SwiftUI
import SwiftData

struct ProgressTabView: View {
    @Query(sort: \DrillResult.timestamp, order: .reverse) private var allResults: [DrillResult]
    @EnvironmentObject private var userProfile: UserProfileStore
    @StateObject private var achievementStore = AchievementStore()

    private var accuracyByModule: [(TrainingModule, Double)] {
        TrainingModule.allCases.compactMap { module in
            let results = allResults.filter { $0.module == module }
            guard results.count >= 3 else { return nil }
            let accuracy = Double(results.filter(\.wasCorrect).count) / Double(results.count)
            return (module, accuracy)
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
        }
    }

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
