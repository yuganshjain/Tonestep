import SwiftUI
import SwiftData

struct FocusSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userProfile: UserProfileStore
    @Query(sort: \DrillResult.timestamp, order: .reverse) private var allResults: [DrillResult]

    @State private var questions: [FocusQuestion] = []
    @State private var currentIndex = 0
    @State private var selected: String? = nil
    @State private var revealed = false
    @State private var score = (correct: 0, total: 0)
    @State private var secondsLeft = 300  // 5 minutes
    @State private var timer: Timer? = nil
    @State private var finished = false
    @State private var questionStart = Date()

    private let totalQuestions = 10

    var body: some View {
        NavigationStack {
            Group {
                if finished {
                    finishScreen
                } else if questions.isEmpty {
                    ProgressView("Building your session…")
                } else {
                    drillScreen
                }
            }
            .navigationTitle("Focus Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { finishSession() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    timerDisplay
                }
            }
        }
        .onAppear { buildSession(); startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Timer Display

    private var timerDisplay: some View {
        let mins = secondsLeft / 60
        let secs = secondsLeft % 60
        let color: Color = secondsLeft > 60 ? .secondary : .red
        return Text(String(format: "%d:%02d", mins, secs))
            .font(.system(.subheadline, design: .monospaced)).fontWeight(.semibold)
            .foregroundStyle(color)
    }

    // MARK: - Drill Screen

    private var drillScreen: some View {
        ScrollView {
            VStack(spacing: 20) {
                progressBar
                questionCard
                optionGrid
                if revealed { nextButton }
                Spacer()
            }
            .padding()
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var progressBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Question \(currentIndex + 1) of \(questions.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(score.correct) correct")
                    .font(.caption).foregroundStyle(.green)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color(.systemFill)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4).fill(Color.purple)
                        .frame(width: geo.size.width * Double(currentIndex) / Double(questions.count), height: 6)
                        .animation(.spring(response: 0.5), value: currentIndex)
                }
            }
            .frame(height: 6)
        }
    }

    private var questionCard: some View {
        let q = questions[currentIndex]
        return VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.purple, Color(red: 0.5, green: 0.1, blue: 0.8)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 110, height: 110)

                VStack(spacing: 4) {
                    Image(systemName: q.module.systemImage)
                        .font(.system(size: 32)).foregroundStyle(.white)
                    Text(q.module.rawValue)
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.white.opacity(0.8))
                }
            }

            Button {
                for midiNote in q.playNotes {
                    AudioEngine.shared.playNote(midiNote: UInt8(midiNote), duration: 1.2)
                }
            } label: {
                Label("Replay", systemImage: "speaker.wave.2.fill")
                    .font(.caption).fontWeight(.medium)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Color.purple.opacity(0.12))
                    .foregroundStyle(Color.purple)
                    .clipShape(Capsule())
            }

            Text(q.prompt)
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
        .onAppear { playCurrentQuestion() }
    }

    private var optionGrid: some View {
        let q = questions[currentIndex]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(q.options, id: \.self) { option in
                let state = optionState(option: option, correct: q.correct)
                Button { submitAnswer(option, question: q) } label: {
                    Text(option)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(state == .idle ? .primary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(optionBg(state), in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(revealed)
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private var nextButton: some View {
        Button {
            if currentIndex + 1 < questions.count {
                currentIndex += 1
                selected = nil
                revealed = false
                questionStart = Date()
            } else {
                finishSession()
            }
        } label: {
            Text(currentIndex + 1 < questions.count ? "Next →" : "Finish Session")
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.purple).foregroundStyle(.white)
                .fontWeight(.semibold).clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Finish Screen

    private var finishScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle().fill(Color.purple.opacity(0.15)).frame(width: 100, height: 100)
                Text("🎯").font(.system(size: 48))
            }
            Text("Focus Complete!").font(.title).fontWeight(.bold)
            Text("\(score.correct)/\(score.total) correct")
                .font(.title2).foregroundStyle(.secondary)

            let accuracy = score.total > 0 ? Double(score.correct) / Double(score.total) : 0
            let bonusXP = 30 + (accuracy >= 0.8 ? 20 : 0)
            VStack(spacing: 8) {
                Text("+\(score.correct * 5 + bonusXP) XP earned")
                    .font(.headline).foregroundStyle(Color.purple)
                if accuracy >= 0.8 {
                    Text("🔥 Accuracy bonus: +20 XP")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            .padding()
            .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))

            Button { dismiss() } label: {
                Text("Done")
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.purple).foregroundStyle(.white)
                    .fontWeight(.semibold).clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Option State

    private enum OptionState { case idle, correct, wrong, dimmed }

    private func optionState(option: String, correct: String) -> OptionState {
        guard revealed, let sel = selected else { return .idle }
        if option == correct { return .correct }
        if option == sel { return .wrong }
        return .dimmed
    }

    private func optionBg(_ s: OptionState) -> Color {
        switch s {
        case .idle:    return Color(.secondarySystemBackground)
        case .correct: return Color.green
        case .wrong:   return Color.red
        case .dimmed:  return Color(.systemFill)
        }
    }

    // MARK: - Logic

    private func playCurrentQuestion() {
        guard currentIndex < questions.count else { return }
        let q = questions[currentIndex]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            for note in q.playNotes {
                AudioEngine.shared.playNote(midiNote: UInt8(note), duration: 1.2)
            }
        }
    }

    private func submitAnswer(_ answer: String, question: FocusQuestion) {
        guard !revealed else { return }
        selected = answer
        revealed = true
        score.total += 1
        let correct = answer == question.correct
        if correct {
            score.correct += 1
            HapticsManager.success()
            userProfile.addXP(5)
        } else {
            HapticsManager.error()
        }
        modelContext.insert(DrillResult(
            module: question.module,
            drillType: question.drillType,
            wasCorrect: correct,
            responseTime: Date().timeIntervalSince(questionStart)
        ))
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if secondsLeft > 0 {
                secondsLeft -= 1
            } else {
                finishSession()
            }
        }
    }

    private func finishSession() {
        timer?.invalidate()
        let accuracy = score.total > 0 ? Double(score.correct) / Double(score.total) : 0
        let bonus = 30 + (accuracy >= 0.8 ? 20 : 0)
        userProfile.addXP(bonus)
        finished = true
    }

    // MARK: - Session Builder

    private func buildSession() {
        let weakModules = computeWeakModules()
        var built: [FocusQuestion] = []

        // Fill from weakest modules first, then random
        let targetModules = weakModules.isEmpty
            ? [TrainingModule.intervalRecognition, .chordRecognition, .scaleRecognition]
            : weakModules

        for _ in 0..<totalQuestions {
            let module = targetModules.randomElement() ?? .intervalRecognition
            if let q = makeQuestion(for: module) {
                built.append(q)
            }
        }
        questions = built.shuffled()
    }

    private func computeWeakModules() -> [TrainingModule] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let recent = allResults.filter { $0.timestamp > cutoff }
        var stats: [TrainingModule: (Int, Int)] = [:]
        for r in recent {
            var s = stats[r.module] ?? (0, 0)
            s.0 += r.wasCorrect ? 1 : 0; s.1 += 1
            stats[r.module] = s
        }
        return stats
            .filter { $0.value.1 >= 3 }
            .sorted { Double($0.value.0) / Double($0.value.1) < Double($1.value.0) / Double($1.value.1) }
            .prefix(3)
            .map(\.key)
    }

    private func makeQuestion(for module: TrainingModule) -> FocusQuestion? {
        switch module {
        case .intervalRecognition, .intervalComparison:
            return makeIntervalQuestion()
        case .chordRecognition, .chordInversions:
            return makeChordQuestion()
        case .scaleRecognition:
            return makeScaleQuestion()
        default:
            return makeIntervalQuestion()
        }
    }

    private func makeIntervalQuestion() -> FocusQuestion {
        let intervals: [(name: String, semitones: Int)] = [
            ("Minor 2nd", 1), ("Major 2nd", 2), ("Minor 3rd", 3), ("Major 3rd", 4),
            ("Perfect 4th", 5), ("Tritone", 6), ("Perfect 5th", 7),
            ("Minor 6th", 8), ("Major 6th", 9), ("Minor 7th", 10), ("Major 7th", 11), ("Octave", 12)
        ]
        let target = intervals.randomElement()!
        let root = Int.random(in: 55...67)
        let options = ([target.name] + intervals.filter { $0.name != target.name }.shuffled().prefix(3).map(\.name)).shuffled()
        return FocusQuestion(
            module: .intervalRecognition,
            drillType: "focus_interval_\(target.name.lowercased().replacingOccurrences(of: " ", with: "_"))",
            prompt: "Ascending interval — what do you hear?",
            playNotes: [root, root + target.semitones],
            options: options,
            correct: target.name
        )
    }

    private func makeChordQuestion() -> FocusQuestion {
        let chords: [(name: String, offsets: [Int])] = [
            ("Major",      [0, 4, 7]),
            ("Minor",      [0, 3, 7]),
            ("Diminished", [0, 3, 6]),
            ("Augmented",  [0, 4, 8]),
        ]
        let target = chords.randomElement()!
        let root = Int.random(in: 55...67)
        let options = chords.map(\.name).shuffled()
        return FocusQuestion(
            module: .chordRecognition,
            drillType: "focus_chord_\(target.name.lowercased())",
            prompt: "What chord quality is this?",
            playNotes: target.offsets.map { root + $0 },
            options: options,
            correct: target.name
        )
    }

    private func makeScaleQuestion() -> FocusQuestion {
        let scales: [(name: String, offsets: [Int])] = [
            ("Major",          [0, 2, 4, 5, 7, 9, 11, 12]),
            ("Natural Minor",  [0, 2, 3, 5, 7, 8, 10, 12]),
            ("Harmonic Minor", [0, 2, 3, 5, 7, 8, 11, 12]),
            ("Dorian",         [0, 2, 3, 5, 7, 9, 10, 12]),
        ]
        let target = scales.randomElement()!
        let root = Int.random(in: 55...62)
        let options = scales.map(\.name).shuffled()
        return FocusQuestion(
            module: .scaleRecognition,
            drillType: "focus_scale_\(target.name.lowercased().replacingOccurrences(of: " ", with: "_"))",
            prompt: "What scale do you hear?",
            playNotes: target.offsets.map { root + $0 },
            options: options,
            correct: target.name
        )
    }
}

struct FocusQuestion {
    let module: TrainingModule
    let drillType: String
    let prompt: String
    let playNotes: [Int]
    let options: [String]
    let correct: String
}
