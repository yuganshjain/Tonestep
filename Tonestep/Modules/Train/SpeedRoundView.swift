import SwiftUI
import SwiftData

struct SpeedRoundView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userProfile: UserProfileStore

    @State private var phase: SpeedPhase = .countdown
    @State private var countdown = 3
    @State private var timeLeft: Double = 60
    @State private var score = 0
    @State private var streak = 0
    @State private var bestStreak = 0
    @State private var totalAnswered = 0
    @State private var countdownTimer: Timer?
    @State private var gameTimer: Timer?

    // Current question
    @State private var currentInterval: Interval = .majorThird
    @State private var rootMidi: UInt8 = 60
    @State private var direction: IntervalDirection = .ascending
    @State private var options: [Interval] = []
    @State private var selectedAnswer: Interval?
    @State private var isPlaying = false
    @State private var showFlash: AnswerButtonState = .idle

    enum SpeedPhase { case countdown, playing, finished }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            switch phase {
            case .countdown: countdownScreen
            case .playing: playingScreen
            case .finished: finishedScreen
            }
        }
        .onAppear { startCountdown() }
        .onDisappear { stopAllTimers() }
    }

    // MARK: - Countdown

    private var countdownScreen: some View {
        VStack(spacing: 20) {
            Text("Speed Round").font(.largeTitle).fontWeight(.black)
            Text("60 seconds · Answer as fast as you can")
                .foregroundStyle(.secondary).multilineTextAlignment(.center)
            ZStack {
                Circle().fill(Color.purple.opacity(0.15)).frame(width: 140, height: 140)
                Text("\(countdown)")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(.purple)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: countdown)
            }
            Text("Get ready!").foregroundStyle(.secondary)
        }
    }

    // MARK: - Playing

    private var playingScreen: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Quit") { stopAllTimers(); dismiss() }.foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 16) {
                    Label("\(score)", systemImage: "checkmark.circle.fill")
                        .font(.subheadline).fontWeight(.bold).foregroundStyle(.green)
                    if streak >= 3 {
                        Label("\(streak)x", systemImage: "flame.fill")
                            .font(.subheadline).fontWeight(.bold).foregroundStyle(.orange)
                    }
                }
            }
            .padding()

            // Timer bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color(.systemFill)).frame(height: 6)
                    Rectangle()
                        .fill(timerColor)
                        .frame(width: geo.size.width * (timeLeft / 60), height: 6)
                        .animation(.linear(duration: 0.1), value: timeLeft)
                }
            }
            .frame(height: 6)

            ScrollView {
                VStack(spacing: 20) {
                    // Time display
                    Text(String(format: "%.0f", timeLeft))
                        .font(.system(size: 56, weight: .black, design: .monospaced))
                        .foregroundStyle(timerColor)
                        .padding(.top, 20)

                    // Play button
                    Button { playCurrentInterval() } label: {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.purple, Color(red:0.5,green:0.1,blue:0.8)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 90, height: 90)
                            Image(systemName: isPlaying ? "waveform" : "play.fill")
                                .font(.system(size: 32)).foregroundStyle(.white)
                                .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                        }
                    }
                    .disabled(isPlaying || selectedAnswer != nil)
                    .buttonStyle(PressableButtonStyle())

                    Text("Identify the \(direction.rawValue.lowercased()) interval")
                        .font(.subheadline).foregroundStyle(.secondary)

                    // Answer grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(options, id: \.self) { interval in
                            Button { answerSelected(interval) } label: {
                                Text(interval.name)
                                    .font(.subheadline).fontWeight(.semibold)
                                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                                    .background(optBg(interval), in: RoundedRectangle(cornerRadius: 14))
                                    .foregroundStyle(optFg(interval))
                                    .animation(.spring(response: 0.2), value: selectedAnswer)
                            }
                            .disabled(selectedAnswer != nil)
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 60)
            }
        }
    }

    // MARK: - Finished

    private var finishedScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: score >= 15 ? "trophy.fill" : "timer")
                .font(.system(size: 56)).foregroundStyle(score >= 15 ? .yellow : .purple)
            Text("Time's Up!").font(.largeTitle).fontWeight(.black)
            VStack(spacing: 8) {
                Text("\(score)").font(.system(size: 72, weight: .black, design: .rounded)).foregroundStyle(.purple)
                Text("correct answers").foregroundStyle(.secondary)
            }
            HStack(spacing: 30) {
                VStack(spacing: 4) {
                    Text("\(totalAnswered)").font(.title2).fontWeight(.bold)
                    Text("Total").font(.caption).foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    let acc = totalAnswered > 0 ? Int(Double(score) / Double(totalAnswered) * 100) : 0
                    Text("\(acc)%").font(.title2).fontWeight(.bold)
                    Text("Accuracy").font(.caption).foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    Text("\(bestStreak)").font(.title2).fontWeight(.bold)
                    Text("Best Streak").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

            let xp = score * 5 + (bestStreak >= 5 ? 25 : 0)
            Text("+\(xp) XP earned").font(.headline).foregroundStyle(.purple)

            Button("Done") { dismiss() }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.purple).foregroundStyle(.white).fontWeight(.bold)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            Spacer()
        }
    }

    // MARK: - Helpers

    private var timerColor: Color {
        if timeLeft > 30 { return .purple }
        if timeLeft > 10 { return .orange }
        return .red
    }

    private func optBg(_ interval: Interval) -> Color {
        guard let sel = selectedAnswer else { return Color(.systemBackground) }
        if interval == currentInterval { return Color.green.opacity(0.2) }
        if interval == sel { return Color.red.opacity(0.2) }
        return Color(.systemBackground).opacity(0.5)
    }

    private func optFg(_ interval: Interval) -> Color {
        guard let sel = selectedAnswer else { return .primary }
        if interval == currentInterval { return .green }
        if interval == sel { return .red }
        return .secondary
    }

    // MARK: - Game Logic

    private func startCountdown() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            withAnimation { countdown -= 1 }
            if countdown <= 0 { t.invalidate(); beginGame() }
        }
    }

    private func beginGame() {
        phase = .playing
        generateQuestion()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { playCurrentInterval() }
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            timeLeft -= 0.1
            if timeLeft <= 0 { endGame() }
        }
    }

    private func generateQuestion() {
        let intervals = Interval.allCases.filter { $0 != .unison && $0 != .octave }
        currentInterval = intervals.randomElement()!
        rootMidi = UInt8.random(in: 48...65)
        direction = Bool.random() ? .ascending : .descending
        selectedAnswer = nil
        isPlaying = false

        var wrong = intervals.filter { $0 != currentInterval }.shuffled().prefix(3).map { $0 }
        options = ([currentInterval] + wrong).shuffled()
    }

    private func playCurrentInterval() {
        guard !isPlaying else { return }
        isPlaying = true
        AudioEngine.shared.playInterval(rootMidi: rootMidi, interval: currentInterval, direction: direction)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { isPlaying = false }
    }

    private func answerSelected(_ answer: Interval) {
        guard selectedAnswer == nil else { return }
        selectedAnswer = answer
        totalAnswered += 1
        let correct = answer == currentInterval
        if correct {
            score += 1; streak += 1; bestStreak = max(bestStreak, streak)
            HapticsManager.success()
        } else {
            streak = 0
            HapticsManager.error()
        }
        let result = DrillResult(module: .intervalRecognition, drillType: "speed_\(currentInterval.name)",
                                  wasCorrect: correct, responseTime: 0)
        modelContext.insert(result)
        DrillRecorder.grade(result, context: modelContext)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if timeLeft > 0 { generateQuestion(); playCurrentInterval() }
        }
    }

    private func endGame() {
        gameTimer?.invalidate()
        let xp = score * 5 + (bestStreak >= 5 ? 25 : 0)
        userProfile.addXP(xp)
        HapticsManager.heavyImpact()
        GameCenterManager.shared.submitScore(score, leaderboardID: GameCenterManager.speedRoundLeaderboard)
        withAnimation { phase = .finished }
    }

    private func stopAllTimers() {
        countdownTimer?.invalidate(); gameTimer?.invalidate()
    }
}
