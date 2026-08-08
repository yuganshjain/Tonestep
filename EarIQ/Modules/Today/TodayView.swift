import SwiftUI
import SwiftData

struct TodayView: View {
    @EnvironmentObject private var userProfile: UserProfileStore
    @Query(sort: \DrillResult.timestamp, order: .reverse) private var allResults: [DrillResult]
    @Query(sort: \SRItem.nextReviewDate) private var srItems: [SRItem]
    @State private var showingDailySession = false

    private var todayCompleted: Bool {
        guard let last = userProfile.lastSessionDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    private var weakSpots: [(String, Double)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recent = allResults.filter { $0.timestamp > cutoff }
        var stats: [String: (Int, Int)] = [:]
        for r in recent {
            var s = stats[r.drillType] ?? (0, 0)
            s.0 += r.wasCorrect ? 1 : 0
            s.1 += 1
            stats[r.drillType] = s
        }
        return stats
            .filter { $0.value.1 >= 3 }
            .map { ($0.key, Double($0.value.0) / Double($0.value.1)) }
            .sorted { $0.1 < $1.1 }
            .prefix(3)
            .map { ($0.0, $0.1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    streakSection
                    xpSection
                    dailySessionCard
                    if !weakSpots.isEmpty { weakSpotsCard }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
        }
        .fullScreenCover(isPresented: $showingDailySession) {
            DailySessionView()
        }
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.title2)
                    Text("\(userProfile.currentStreak)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                }
                Text("day streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 50)

            VStack(spacing: 4) {
                Text("\(userProfile.longestStreak)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text("best streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - XP Section

    private var xpSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(EarIQLevel.title(for: userProfile.xp))
                        .font(.headline)
                    Text("Level \(userProfile.level + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(userProfile.xp) XP")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.purple)
            }

            let next = EarIQLevel.nextThreshold(for: userProfile.xp)
            let current = userProfile.level > 0 ? EarIQLevel.thresholds[userProfile.level].0 : 0
            let progress = next > current ? Double(userProfile.xp - current) / Double(next - current) : 1.0
            ProgressView(value: min(progress, 1.0))
                .tint(.purple)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Daily Session Card

    private var dailySessionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(todayCompleted ? "Session Complete!" : "Daily Session")
                        .font(.headline)
                    Text(todayCompleted
                         ? "Come back tomorrow to keep your streak."
                         : "~\(userProfile.sessionLength.rawValue) min • Personalized for you")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if todayCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                }
            }

            Button {
                showingDailySession = true
            } label: {
                Label(todayCompleted ? "Practice More" : "Start Session",
                      systemImage: todayCompleted ? "play.circle" : "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(todayCompleted ? Color.purple.opacity(0.15) : Color.purple)
                    .foregroundStyle(todayCompleted ? .purple : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Weak Spots Card

    private var weakSpotsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Weak Spots")
                .font(.headline)
            ForEach(weakSpots, id: \.0) { drillType, accuracy in
                HStack {
                    Text(drillType.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(accuracy * 100))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(accuracy < 0.6 ? .red : .orange)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}
