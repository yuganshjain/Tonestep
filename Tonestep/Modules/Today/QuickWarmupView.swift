import SwiftUI
import SwiftData

struct QuickWarmupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userProfile: UserProfileStore

    private let totalQuestions = 5
    @State private var current = 0
    @State private var score = 0
    @State private var isComplete = false
    @State private var selectedAnswer: String?
    @State private var options: [String] = []
    @State private var isPlaying = false
    @State private var questions: [WarmupQuestion] = []

    struct WarmupQuestion {
        enum Kind { case interval(Interval, IntervalDirection), chord(ChordQuality), note(UInt8) }
        let kind: Kind
        let root: UInt8
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if isComplete { completionView } else { questionView }
            }
        }
        .onAppear { buildQuestions() }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Skip") { dismiss() }.foregroundStyle(.secondary)
                Spacer()
                Text("Quick Warmup").font(.headline)
                Spacer()
                Text("\(current + 1)/\(totalQuestions)")
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.orange)
            }
            .padding(.horizontal).padding(.top, 16)

            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<totalQuestions, id: \.self) { i in
                    Circle()
                        .fill(i < current ? Color.orange : i == current ? Color.orange.opacity(0.5) : Color(.systemFill))
                        .frame(width: 8, height: 8)
                        .animation(.spring(response: 0.3), value: current)
                }
            }
            .padding(.bottom, 8)
        }
    }

    private var questionView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Play button
                Button { playQuestion() } label: {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.orange, Color(red:0.9,green:0.4,blue:0.0)],
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
                        Button { pick(opt) } label: {
                            HStack {
                                Text(opt).foregroundStyle(fg(opt))
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
                            .background(bg(opt), in: RoundedRectangle(cornerRadius: 14))
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
        }
    }

    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: score == totalQuestions ? "flame.fill" : "checkmark.seal.fill")
                .font(.system(size: 56)).foregroundStyle(.orange)
            Text("Warmup Complete!").font(.title).fontWeight(.bold)
            Text("\(score)/\(totalQuestions) correct · \(score * 5) XP earned")
                .foregroundStyle(.secondary)
            Button("Start Training") { dismiss() }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.orange).foregroundStyle(.white).fontWeight(.bold)
                .clipShape(RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
            Spacer()
        }
    }

    // MARK: Logic

    private var q: WarmupQuestion { questions[min(current, questions.count - 1)] }

    private var questionPrompt: String {
        switch q.kind {
        case .interval(_, let d): return "Identify the \(d.rawValue.lowercased()) interval"
        case .chord: return "What chord quality is this?"
        case .note: return "Name the note you hear"
        }
    }

    private var correctAnswer: String {
        switch q.kind {
        case .interval(let i, _): return i.name
        case .chord(let qual): return qual.rawValue
        case .note(let midi): return ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"][Int(midi) % 12]
        }
    }

    private func fg(_ opt: String) -> Color {
        guard let sel = selectedAnswer else { return .primary }
        if opt == correctAnswer { return .green }
        if opt == sel { return .red }
        return .secondary
    }

    private func bg(_ opt: String) -> Color {
        guard let sel = selectedAnswer else { return Color(.systemBackground) }
        if opt == correctAnswer { return Color.green.opacity(0.15) }
        if opt == sel { return Color.red.opacity(0.15) }
        return Color(.systemBackground).opacity(0.5)
    }

    private func buildQuestions() {
        let intervals = Interval.allCases.filter { $0 != .unison }.shuffled()
        let chords: [ChordQuality] = [.major, .minor, .diminished, .augmented]
        let notes: [UInt8] = [48,50,52,53,55,57,60,62,64,65,67,69,72]
        questions = [
            WarmupQuestion(kind: .interval(intervals[0], .ascending), root: UInt8.random(in: 52...65)),
            WarmupQuestion(kind: .chord(chords.randomElement()!), root: UInt8.random(in: 48...65)),
            WarmupQuestion(kind: .interval(intervals[1], .descending), root: UInt8.random(in: 52...65)),
            WarmupQuestion(kind: .note(notes.randomElement()!), root: 0),
            WarmupQuestion(kind: .interval(intervals[2], .ascending), root: UInt8.random(in: 52...65)),
        ]
        generateOptions()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { playQuestion() }
    }

    private func generateOptions() {
        guard current < questions.count else { return }
        switch q.kind {
        case .interval(let i, _):
            let pool = Interval.allCases.filter { $0 != i }.shuffled().prefix(3).map(\.name)
            options = ([i.name] + pool).shuffled()
        case .chord(let qual):
            let chords: [ChordQuality] = [.major, .minor, .diminished, .augmented]
            let pool = chords.filter { $0 != qual }.prefix(3).map(\.rawValue)
            options = ([qual.rawValue] + pool).shuffled()
        case .note(let midi):
            let names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
            let correct = names[Int(midi) % 12]
            let pool = names.filter { $0 != correct }.shuffled().prefix(3)
            options = ([correct] + pool).shuffled()
        }
    }

    private func playQuestion() {
        guard !isPlaying else { return }
        isPlaying = true
        switch q.kind {
        case .interval(let i, let d):
            AudioEngine.shared.playInterval(rootMidi: q.root, interval: i, direction: d)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { isPlaying = false }
        case .chord(let qual):
            AudioEngine.shared.playChord(rootMidi: q.root, quality: qual)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { isPlaying = false }
        case .note(let midi):
            AudioEngine.shared.playNote(midiNote: midi, duration: 1.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { isPlaying = false }
        }
    }

    private func pick(_ answer: String) {
        guard selectedAnswer == nil else { return }
        selectedAnswer = answer
        let correct = answer == correctAnswer
        correct ? HapticsManager.success() : HapticsManager.error()
        if correct { score += 1 }
    }

    private func advance() {
        if current + 1 < totalQuestions {
            current += 1
            selectedAnswer = nil; isPlaying = false
            generateOptions()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { playQuestion() }
        } else {
            userProfile.addXP(score * 5)
            withAnimation { isComplete = true }
        }
    }
}
