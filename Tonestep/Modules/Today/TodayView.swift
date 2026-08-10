import SwiftUI
import SwiftData

struct TodayView: View {
    @EnvironmentObject private var userProfile: UserProfileStore
    @Query(sort: \DrillResult.timestamp, order: .reverse) private var allResults: [DrillResult]
    @State private var showingDailySession = false
    @State private var showingWarmup = false
    @State private var showingFocus = false
    @State private var flameScale: CGFloat = 1.0

    private var todayCompleted: Bool {
        guard let last = userProfile.lastSessionDate else { return false }
        return Calendar.current.isDateInToday(last)
    }

    private var weakModulesForToday: [(TrainingModule, Double)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let recent = allResults.filter { $0.timestamp > cutoff }
        var stats: [TrainingModule: (Int, Int)] = [:]
        for r in recent {
            var s = stats[r.module] ?? (0, 0)
            s.0 += r.wasCorrect ? 1 : 0; s.1 += 1
            stats[r.module] = s
        }
        return stats.filter { $0.value.1 >= 3 }
            .map { ($0.key, Double($0.value.0) / Double($0.value.1)) }
            .sorted { $0.1 < $1.1 }.prefix(3).map { ($0.0, $0.1) }
    }

    private var todayFocusLabel: String {
        let modules = weakModulesForToday.prefix(2).map { $0.0.rawValue }
        if modules.isEmpty { return "Personalized for you" }
        return "Focus: \(modules.joined(separator: " · "))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    mascotHeader
                    heroCard
                    xpCard
                    HStack(spacing: 12) {
                        warmupCard
                        focusCard
                    }
                    dailySessionCard
                    if !weakModulesForToday.isEmpty { weakSpotsCard }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appPurple)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appPurple, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
        }
        .background(Color.appPurple.ignoresSafeArea())
        .fullScreenCover(isPresented: $showingDailySession) { DailySessionView() }
        .fullScreenCover(isPresented: $showingFocus) { FocusSessionView() }
        .sheet(isPresented: $showingWarmup) { QuickWarmupView() }
        .onAppear { GameCenterManager.shared.authenticate() }
    }

    // MARK: - Mascot Header

    private var mascotHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Good \(timeGreeting),")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                Text("Musician! 👋")
                    .font(.title2).fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("Let's train your ears today")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            MascotView(size: 90)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private var timeGreeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 0..<12: return "morning"
        case 12..<17: return "afternoon"
        default: return "evening"
        }
    }

    // MARK: - Hero Streak Card

    private var heroCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
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

                    VStack(alignment: .trailing, spacing: 4) {
                        if let label = userProfile.multiplierLabel {
                            Text(label)
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.yellow.opacity(0.25))
                                .foregroundStyle(Color(red: 1.0, green: 0.95, blue: 0.4))
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Color.yellow.opacity(0.5), lineWidth: 1))
                        }
                        VStack(spacing: 2) {
                            Text("Best")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                            Text("\(userProfile.longestStreak)")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
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

    // MARK: - Focus Mode Card

    private var focusCard: some View {
        Button { showingFocus = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("🎯")
                    .font(.system(size: 28))
                HStack(spacing: 4) {
                    Text("Focus").font(.subheadline).fontWeight(.bold)
                        .foregroundStyle(TrainingModule.pastelText)
                    Text("SMART")
                        .font(.system(size: 7, weight: .bold))
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(Color.appPurple).foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                Text("5 min · \(weakModulesForToday.isEmpty ? "All modules" : "Weak spots")")
                    .font(.caption2)
                    .foregroundStyle(TrainingModule.pastelSubtext)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(red: 0.91, green: 0.88, blue: 1.00), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Warmup Card

    private var warmupCard: some View {
        Button { showingWarmup = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("🔥")
                    .font(.system(size: 28))
                Text("Warmup")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundStyle(TrainingModule.pastelText)
                Text("2 min · 5 Qs")
                    .font(.caption2)
                    .foregroundStyle(TrainingModule.pastelSubtext)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(red: 1.00, green: 0.89, blue: 0.84), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressableButtonStyle())
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
                        .foregroundStyle(TrainingModule.pastelText)
                }
                Spacer()
                Text(TonestepLevel.title(for: userProfile.xp))
                    .font(.subheadline)
                    .foregroundStyle(Color.appPurple)
                    .fontWeight(.medium)
            }

            AnimatedXPBar(xp: userProfile.xp)

            HStack {
                Text("\(userProfile.xp) XP")
                    .font(.caption).foregroundStyle(TrainingModule.pastelSubtext)
                Spacer()
                let next = TonestepLevel.nextThreshold(for: userProfile.xp)
                Text("\(next) XP to Level \(userProfile.level + 2)")
                    .font(.caption).foregroundStyle(TrainingModule.pastelSubtext)
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Daily Session Card

    private var dailySessionCard: some View {
        Button { showingDailySession = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(todayCompleted
                              ? Color.green.opacity(0.15)
                              : Color.appPurple)
                        .frame(width: 52, height: 52)
                    Image(systemName: todayCompleted ? "checkmark" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(todayCompleted ? .green : .white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(todayCompleted ? "Session Complete" : "Daily Session")
                        .font(.headline)
                        .foregroundStyle(TrainingModule.pastelText)
                    Text(todayCompleted
                         ? "Come back tomorrow to continue your streak"
                         : "~\(userProfile.sessionLength.rawValue) min · \(todayFocusLabel)")
                        .font(.caption)
                        .foregroundStyle(TrainingModule.pastelSubtext)
                }
                Spacer()
                if !todayCompleted {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(TrainingModule.pastelSubtext)
                }
            }
            .padding(16)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Weak Spots Card

    private var weakSpotsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                Text("Your Weak Spots").font(.headline)
                    .foregroundStyle(TrainingModule.pastelText)
                Spacer()
                Text("Tap to train").font(.caption2).foregroundStyle(TrainingModule.pastelSubtext)
            }
            ForEach(weakModulesForToday, id: \.0) { module, accuracy in
                NavigationLink(destination: todayModuleDestination(for: module)) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(module.pastelColor)
                                .frame(width: 34, height: 34)
                            Text(module.moduleEmoji)
                                .font(.system(size: 16))
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(module.rawValue).font(.subheadline)
                                .foregroundStyle(TrainingModule.pastelText)
                            SwiftUI.ProgressView(value: accuracy)
                                .tint(accuracy < 0.5 ? .red : .orange)
                        }
                        Spacer()
                        Text("\(Int(accuracy * 100))%")
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(accuracy < 0.5 ? .red : .orange)
                    }
                    .padding(10)
                    .background(Color(red: 0.97, green: 0.97, blue: 1.0), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private func todayModuleDestination(for module: TrainingModule) -> some View {
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

// MARK: - Animated XP Bar

struct AnimatedXPBar: View {
    let xp: Int
    @State private var animatedProgress: Double = 0

    private var progress: Double {
        let current = TonestepLevel.level(for: xp)
        let lo = TonestepLevel.thresholds[current].0
        let hi = TonestepLevel.nextThreshold(for: xp)
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
