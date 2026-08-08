import SwiftUI
import SwiftData

struct TodayView: View {
    @EnvironmentObject private var userProfile: UserProfileStore
    @Query(sort: \DrillResult.timestamp, order: .reverse) private var allResults: [DrillResult]
    @State private var showingDailySession = false
    @State private var flameScale: CGFloat = 1.0

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
            s.0 += r.wasCorrect ? 1 : 0; s.1 += 1
            stats[r.drillType] = s
        }
        return stats.filter { $0.value.1 >= 3 }
            .map { ($0.key, Double($0.value.0) / Double($0.value.1)) }
            .sorted { $0.1 < $1.1 }.prefix(3).map { ($0.0, $0.1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                    xpCard
                    dailySessionCard
                    if !weakSpots.isEmpty { weakSpotsCard }
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 110)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
        }
        .fullScreenCover(isPresented: $showingDailySession) {
            DailySessionView()
        }
    }

    // MARK: - Hero Streak Card

    private var heroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.42, green: 0.20, blue: 0.90),
                                 Color(red: 0.60, green: 0.10, blue: 0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    HStack(alignment: .center, spacing: 10) {
                        Text("🔥")
                            .font(.system(size: 32))
                            .scaleEffect(flameScale)
                            .animation(
                                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: flameScale
                            )
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(userProfile.currentStreak)")
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            Text("day streak")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text("Best")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                        Text("\(userProfile.longestStreak)")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }

                Text(streakMotivation)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .frame(height: 145)
        .onAppear { flameScale = 1.12 }
    }

    private var streakMotivation: String {
        switch userProfile.currentStreak {
        case 0: return "Start your streak today!"
        case 1: return "Day 1 — every expert was once a beginner"
        case 2...6: return "Building momentum — keep going!"
        case 7...13: return "One week strong! You're forming a habit"
        case 14...29: return "Two weeks! Your ears are improving"
        case 30...: return "A month of dedicated training! 🎵"
        default: return "Keep going!"
        }
    }

    // MARK: - XP Card

    private var xpCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Color(red: 1, green: 0.85, blue: 0.2))
                    Text("Level \(userProfile.level + 1)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Spacer()
                Text(EarIQLevel.title(for: userProfile.xp))
                    .font(.subheadline)
                    .foregroundStyle(Color.purple)
                    .fontWeight(.medium)
            }

            AnimatedXPBar(xp: userProfile.xp)

            HStack {
                Text("\(userProfile.xp) XP")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                let next = EarIQLevel.nextThreshold(for: userProfile.xp)
                Text("\(next) XP to Level \(userProfile.level + 2)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Daily Session Card

    private var dailySessionCard: some View {
        Button { showingDailySession = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AnyShapeStyle(todayCompleted
                              ? AnyShapeStyle(Color.green.opacity(0.15))
                              : AnyShapeStyle(LinearGradient(colors: [Color.purple, Color(red: 0.5, green: 0.1, blue: 0.8)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing))))
                        .frame(width: 52, height: 52)
                    Image(systemName: todayCompleted ? "checkmark" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(todayCompleted ? .green : .white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(todayCompleted ? "Session Complete" : "Daily Session")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(todayCompleted
                         ? "Come back tomorrow to continue your streak"
                         : "~\(userProfile.sessionLength.rawValue) min • Personalized for you")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !todayCompleted {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(.background, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Weak Spots Card

    private var weakSpotsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Practice These")
                    .font(.headline)
            }
            ForEach(weakSpots, id: \.0) { drillType, accuracy in
                HStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accuracy < 0.5 ? Color.red.opacity(0.8) : Color.orange.opacity(0.8))
                        .frame(width: 4, height: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(drillType.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.subheadline)
                        SwiftUI.ProgressView(value: accuracy)
                            .tint(accuracy < 0.5 ? .red : .orange)
                    }
                    Spacer()
                    Text("\(Int(accuracy * 100))%")
                        .font(.subheadline).fontWeight(.bold)
                        .foregroundStyle(accuracy < 0.5 ? .red : .orange)
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Animated XP Bar

struct AnimatedXPBar: View {
    let xp: Int
    @State private var animatedProgress: Double = 0

    private var progress: Double {
        let current = EarIQLevel.level(for: xp)
        let lo = EarIQLevel.thresholds[current].0
        let hi = EarIQLevel.nextThreshold(for: xp)
        guard hi > lo else { return 1 }
        return min(Double(xp - lo) / Double(hi - lo), 1.0)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemFill))
                    .frame(height: 10)
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color(red: 0.7, green: 0.3, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * animatedProgress, height: 10)
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: animatedProgress)
            }
        }
        .frame(height: 10)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                animatedProgress = progress
            }
        }
        .onChange(of: xp) { _, _ in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: - Pressable Button Style

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
