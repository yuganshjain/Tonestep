import SwiftUI
import SwiftData

// MARK: - Seeded RNG

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
}

// MARK: - Daily Challenge Question

private enum DailyQuestion: Identifiable {
    case interval(root: UInt8, interval: Interval, direction: IntervalDirection)
    case chord(root: UInt8, quality: ChordQuality)
    case note(midi: UInt8)

    var id: String {
        switch self {
        case .interval(let r, let i, let d): return "int_\(r)_\(i)_\(d)"
        case .chord(let r, let q): return "chord_\(r)_\(q)"
        case .note(let m): return "note_\(m)"
        }
    }

    var moduleType: TrainingModule {
        switch self { case .interval: return .intervalRecognition; case .chord: return .chordRecognition; case .note: return .noteIdentification }
    }
}

private func buildDailyQuestions(seed: UInt64) -> [DailyQuestion] {
    var rng = SeededRNG(seed: seed)
    var questions: [DailyQuestion] = []
    let roots: [UInt8] = [48,50,52,53,55,57,60,62,64,65,67,69,72]
    let intervals = Interval.allCases.filter { $0 != .unison }
    let freeChords: [ChordQuality] = [.major, .minor, .diminished, .augmented]
    let notePool: [UInt8] = [48,50,52,53,55,57,59,60,62,64,65,67,69,71,72]

    for i in 0..<10 {
        let root = roots[Int(rng.next() % UInt64(roots.count))]
        switch i % 3 {
        case 0:
            let interval = intervals[Int(rng.next() % UInt64(intervals.count))]
            let direction = IntervalDirection.allCases[Int(rng.next() % 2)]
            questions.append(.interval(root: root, interval: interval, direction: direction))
        case 1:
            let chord = freeChords[Int(rng.next() % UInt64(freeChords.count))]
            questions.append(.chord(root: root, quality: chord))
        default:
            let note = notePool[Int(rng.next() % UInt64(notePool.count))]
            questions.append(.note(midi: note))
        }
    }
    return questions
}

// MARK: - ChallengesView

struct ChallengesView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @EnvironmentObject private var userProfile: UserProfileStore
    @Environment(\.modelContext) private var modelContext

    @State private var showingChallenge = false
    @State private var bestScore: Int = UserDefaults.standard.integer(forKey: "dailyChallengeBest")
    @State private var todayScore: Int? = {
        let key = "dailyChallengeDate"
        let scoreKey = "dailyChallengeScore"
        if let saved = UserDefaults.standard.string(forKey: key) {
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            if saved == fmt.string(from: Date()) {
                return UserDefaults.standard.integer(forKey: scoreKey)
            }
        }
        return nil
    }()

    private var todaySeed: UInt64 {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: Date())
        return UInt64((comps.year ?? 2024) * 10000 + (comps.month ?? 1) * 100 + (comps.day ?? 1))
    }

    private var secondsUntilMidnight: Int {
        let cal = Calendar.current
        let now = Date()
        let nextMidnight = cal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTime) ?? now
        return Int(nextMidnight.timeIntervalSince(now))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    dailyChallengeCard
                    personalBestsCard
                    howItWorksCard
                }
                .padding()
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(isPresented: $showingChallenge) {
                DailyChallengeSession(
                    questions: buildDailyQuestions(seed: todaySeed),
                    onComplete: { score in
                        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
                        UserDefaults.standard.set(fmt.string(from: Date()), forKey: "dailyChallengeDate")
                        UserDefaults.standard.set(score, forKey: "dailyChallengeScore")
                        if score > bestScore {
                            bestScore = score
                            UserDefaults.standard.set(score, forKey: "dailyChallengeBest")
                        }
                        todayScore = score
                        userProfile.addXP(score * 3)
                    }
                )
            }
        }
    }

    private var dailyChallengeCard: some View {
        VStack(spacing: 0) {
            // Header
            LinearGradient(colors: [Color(red:0.8,green:0.6,blue:0.0), Color(red:0.9,green:0.4,blue:0.0)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Daily Challenge", systemImage: "trophy.fill")
                                .font(.headline).fontWeight(.bold).foregroundStyle(.white)
                            Text("10 questions · Same for everyone")
                                .font(.caption).foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Resets in")
                                .font(.caption2).foregroundStyle(.white.opacity(0.7))
                            Text(formatCountdown(secondsUntilMidnight))
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                    }

                    if let score = todayScore {
                        HStack(spacing: 12) {
                            VStack {
                                Text("\(score)/10")
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Today").font(.caption2).foregroundStyle(.white.opacity(0.7))
                            }
                            Divider().background(.white.opacity(0.4)).frame(height: 40)
                            VStack {
                                Text("\(bestScore)/10")
                                    .font(.system(size: 32, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Best").font(.caption2).foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer()
                            Image(systemName: score == 10 ? "star.fill" : "checkmark.circle.fill")
                                .font(.system(size: 40)).foregroundStyle(.white)
                        }

                        Text("Come back tomorrow for a new challenge!")
                            .font(.caption).foregroundStyle(.white.opacity(0.8))
                    } else {
                        Button { showingChallenge = true } label: {
                            Text("Start Today's Challenge")
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(Color.white)
                                .foregroundStyle(Color(red:0.8,green:0.4,blue:0.0))
                                .fontWeight(.bold)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(20)
            )
            .frame(minHeight: 160)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    private var personalBestsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Bests").font(.headline)
            ForEach([TrainingModule.intervalRecognition, .chordRecognition, .scaleRecognition, .melodicDictation], id: \.self) { module in
                HStack {
                    Image(systemName: module.systemImage).foregroundStyle(.purple).frame(width: 22)
                    Text(module.rawValue).font(.subheadline)
                    Spacer()
                    Text("—").foregroundStyle(.secondary).font(.subheadline)
                }
            }
            Text("Complete sessions to set personal bests.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var howItWorksCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("How it works", systemImage: "info.circle.fill").font(.headline).foregroundStyle(.blue)
            ForEach([
                ("1", "Same 10 questions for all EarIQ users each day"),
                ("2", "Questions change at midnight in your timezone"),
                ("3", "Each correct answer earns +3 XP bonus"),
                ("4", "Beat your best score to climb the ranks"),
            ], id: \.0) { num, text in
                HStack(alignment: .top, spacing: 10) {
                    Text(num)
                        .font(.caption).fontWeight(.bold)
                        .frame(width: 20, height: 20)
                        .background(Color.blue.opacity(0.15), in: Circle())
                        .foregroundStyle(.blue)
                    Text(text).font(.subheadline)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func formatCountdown(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

// MARK: - Daily Challenge Session

fileprivate struct DailyChallengeSession: View {
    let questions: [DailyQuestion]
    let onComplete: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var score = 0
    @State private var timeElapsed: Double = 0
    @State private var timer: Timer?
    @State private var isComplete = false
    @State private var selectedAnswer: String?
    @State private var options: [String] = []
    @State private var isPlaying = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button("Exit") { timer?.invalidate(); dismiss() }
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(currentIndex + 1)/\(questions.count)")
                        .font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Label(String(format: "%.1fs", timeElapsed), systemImage: "timer")
                        .font(.subheadline).foregroundStyle(.orange)
                }
                .padding()

                // Progress
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color(.systemFill)).frame(height: 4)
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: geo.size.width * Double(currentIndex) / Double(questions.count), height: 4)
                            .animation(.spring(response: 0.4), value: currentIndex)
                    }
                }
                .frame(height: 4)

                if isComplete {
                    completeScreen
                } else {
                    questionView
                }
            }
        }
        .onAppear { startTimer(); generateOptions() }
    }

    private var questionView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Play button
                Button { playCurrentQuestion() } label: {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.orange, Color(red:0.9,green:0.3,blue:0.0)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 100, height: 100)
                        Image(systemName: isPlaying ? "waveform" : "play.fill")
                            .font(.system(size: 36)).foregroundStyle(.white)
                            .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                    }
                }
                .disabled(isPlaying || selectedAnswer != nil)
                .buttonStyle(PressableButtonStyle())

                Text(questionPrompt).font(.headline).multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    ForEach(options, id: \.self) { opt in
                        Button { selectAnswer(opt) } label: {
                            HStack {
                                Text(opt).font(.subheadline).foregroundStyle(optColor(opt))
                                Spacer()
                                if selectedAnswer != nil {
                                    if opt == correctAnswer {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    } else if opt == selectedAnswer {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                    }
                                }
                            }
                            .padding(14)
                            .background(optBg(opt), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(selectedAnswer != nil)
                        .buttonStyle(PressableButtonStyle())
                    }
                }

                if selectedAnswer != nil {
                    Button("Next →") { advance() }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color.orange).foregroundStyle(.white).fontWeight(.semibold)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .buttonStyle(PressableButtonStyle())
                }
            }
            .padding()
            .padding(.bottom, 60)
        }
    }

    private var completeScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: score == questions.count ? "star.fill" : "trophy.fill")
                .font(.system(size: 60)).foregroundStyle(.yellow)
            Text("Challenge Complete!").font(.title).fontWeight(.bold)
            VStack(spacing: 8) {
                Text("\(score)/\(questions.count)").font(.system(size: 56, weight: .black, design: .rounded)).foregroundStyle(.orange)
                Text("correct answers").foregroundStyle(.secondary)
            }
            Text("Time: \(String(format: "%.1f", timeElapsed))s • +\(score * 3) XP bonus")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("Done") { timer?.invalidate(); onComplete(score); dismiss() }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.orange).foregroundStyle(.white).fontWeight(.bold)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            Spacer()
        }
    }

    private var questionPrompt: String {
        switch questions[currentIndex] {
        case .interval(_, _, let d): return "Identify this \(d.rawValue.lowercased()) interval"
        case .chord: return "Identify this chord quality"
        case .note: return "Name the note you hear"
        }
    }

    private var correctAnswer: String {
        switch questions[currentIndex] {
        case .interval(_, let i, _): return i.name
        case .chord(_, let q): return q.rawValue
        case .note(let m): return ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"][Int(m) % 12]
        }
    }

    private func optColor(_ opt: String) -> Color {
        guard let sel = selectedAnswer else { return .primary }
        if opt == correctAnswer { return .green }
        if opt == sel { return .red }
        return .secondary
    }

    private func optBg(_ opt: String) -> Color {
        guard let sel = selectedAnswer else { return Color(.systemBackground) }
        if opt == correctAnswer { return Color.green.opacity(0.15) }
        if opt == sel { return Color.red.opacity(0.15) }
        return Color(.systemBackground).opacity(0.5)
    }

    private func generateOptions() {
        let q = questions[currentIndex]
        switch q {
        case .interval(_, let correct, _):
            let pool = Interval.allCases.filter { $0 != correct }.shuffled().prefix(3).map(\.name)
            options = ([correct.name] + pool).shuffled()
        case .chord(_, let correct):
            let pool = ChordQuality.allCases.filter { $0 != correct }.shuffled().prefix(3).map(\.rawValue)
            options = ([correct.rawValue] + pool).shuffled()
        case .note(let midi):
            let names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
            let correct = names[Int(midi) % 12]
            let pool = names.filter { $0 != correct }.shuffled().prefix(3)
            options = ([correct] + pool).shuffled()
        }
    }

    private func playCurrentQuestion() {
        guard !isPlaying else { return }
        isPlaying = true
        switch questions[currentIndex] {
        case .interval(let r, let i, let d):
            AudioEngine.shared.playInterval(rootMidi: r, interval: i, direction: d)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { isPlaying = false }
        case .chord(let r, let q):
            AudioEngine.shared.playChord(rootMidi: r, quality: q)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { isPlaying = false }
        case .note(let m):
            AudioEngine.shared.playNote(midiNote: m, duration: 1.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { isPlaying = false }
        }
    }

    private func selectAnswer(_ answer: String) {
        guard selectedAnswer == nil else { return }
        selectedAnswer = answer
        let correct = answer == correctAnswer
        correct ? HapticsManager.success() : HapticsManager.error()
        if correct { score += 1 }
    }

    private func advance() {
        if currentIndex + 1 < questions.count {
            currentIndex += 1
            selectedAnswer = nil
            isPlaying = false
            generateOptions()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { playCurrentQuestion() }
        } else {
            timer?.invalidate()
            isComplete = true
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            timeElapsed += 0.1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { playCurrentQuestion() }
    }
}
