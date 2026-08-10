import SwiftUI
import SwiftData

// MARK: - Module wrapper

struct IntervalComparisonModuleView: View {
    var body: some View {
        NavigationStack {
            IntervalComparisonDrillView()
                .navigationTitle("Interval Comparison")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Answer type

private enum ComparisonAnswer: String, CaseIterable {
    case firstWider = "First is Wider"
    case secondWider = "Second is Wider"
    case equal = "They're Equal"

    var icon: String {
        switch self { case .firstWider: return "arrow.up.left.circle.fill"
                      case .secondWider: return "arrow.up.right.circle.fill"
                      case .equal: return "equal.circle.fill" }
    }
}

// MARK: - Drill View

struct IntervalComparisonDrillView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userProfile: UserProfileStore

    @State private var intervalA: Interval = .majorThird
    @State private var intervalB: Interval = .perfectFifth
    @State private var rootA: UInt8 = 60
    @State private var rootB: UInt8 = 60
    @State private var phase: CompPhase = .idle
    @State private var selected: ComparisonAnswer?
    @State private var score = (correct: 0, total: 0)
    @State private var drillStart = Date()

    enum CompPhase { case idle, playingA, playingB, ready }

    private var correctAnswer: ComparisonAnswer {
        if intervalA.rawValue > intervalB.rawValue { return .firstWider }
        if intervalB.rawValue > intervalA.rawValue { return .secondWider }
        return .equal
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                scoreBar
                intervalDisplay
                playButtons
                if phase == .ready || selected != nil { answerSection }
                if selected != nil { nextButton }
            }
            .padding()
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { newDrill() }
    }

    // MARK: Sub-views

    private var scoreBar: some View {
        HStack {
            Label("\(score.correct)/\(score.total)", systemImage: "checkmark.circle.fill")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.green)
            Spacer()
            Text("Which interval spans more semitones?")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var intervalDisplay: some View {
        HStack(spacing: 16) {
            intervalBox(label: "A", interval: intervalA, state: displayState(for: .A), isPlaying: phase == .playingA)
            Image(systemName: "arrow.left.arrow.right")
                .font(.title2).foregroundStyle(.secondary)
            intervalBox(label: "B", interval: intervalB, state: displayState(for: .B), isPlaying: phase == .playingB)
        }
    }

    private func intervalBox(label: String, interval: Interval, state: BoxState, isPlaying: Bool) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(state.background).frame(width: 72, height: 72)
                if isPlaying {
                    Image(systemName: "waveform")
                        .font(.system(size: 28)).foregroundStyle(.white)
                        .symbolEffect(.variableColor.iterative, isActive: true)
                } else {
                    Text(label).font(.system(size: 32, weight: .black, design: .rounded)).foregroundStyle(.white)
                }
            }
            if let sel = selected {
                Text(interval.name).font(.caption).fontWeight(.semibold).foregroundStyle(state.labelColor)
                Text("\(interval.rawValue) semitones").font(.system(size: 9)).foregroundStyle(.secondary)
            } else {
                Text("Interval \(label)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(state.border, lineWidth: 2)
        )
    }

    private var playButtons: some View {
        VStack(spacing: 10) {
            Button { playInterval(which: .A) } label: {
                Label(phase == .playingA ? "Playing A…" : "Play Interval A", systemImage: "play.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(phase == .playingA ? Color.blue.opacity(0.5) : Color.blue)
                    .foregroundStyle(.white).fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(phase == .playingA || phase == .playingB || selected != nil)

            Button { playInterval(which: .B) } label: {
                Label(phase == .playingB ? "Playing B…" : "Play Interval B", systemImage: "play.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(phase == .playingB ? Color.orange.opacity(0.5) : Color.orange)
                    .foregroundStyle(.white).fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(phase == .playingA || phase == .playingB || selected != nil)

            if phase == .idle {
                Text("Play both intervals first").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var answerSection: some View {
        VStack(spacing: 10) {
            if selected == nil {
                Text("Which spans more semitones?").font(.headline)
            }
            ForEach(ComparisonAnswer.allCases, id: \.self) { answer in
                Button { selectAnswer(answer) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: answer.icon)
                            .font(.title3).foregroundStyle(answerFg(answer))
                        Text(answer.rawValue).font(.subheadline).fontWeight(.semibold)
                        Spacer()
                        if selected != nil {
                            if answer == correctAnswer {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            } else if answer == selected {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(14)
                    .background(answerBg(answer), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(answerFg(answer))
                }
                .disabled(selected != nil)
                .buttonStyle(PressableButtonStyle())
            }

            if let sel = selected {
                let correct = sel == correctAnswer
                HStack {
                    Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(correct ? .green : .red)
                    Text(correct ? "Correct! +15 XP"
                         : "\(intervalA.name) = \(intervalA.rawValue) st · \(intervalB.name) = \(intervalB.rawValue) st")
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(correct ? .green : .red)
                    Spacer()
                }
                .padding(12)
                .background((correct ? Color.green : Color.red).opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                .transition(.opacity)
            }
        }
    }

    private var nextButton: some View {
        Button { newDrill() } label: {
            Text("Next Comparison").frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color(red:0.2,green:0.5,blue:0.9)).foregroundStyle(.white)
                .fontWeight(.semibold).clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: Helpers

    enum Which { case A, B }
    enum BoxState {
        case neutral, active, correct, wrong, revealed
        var background: LinearGradient {
            switch self {
            case .neutral: return LinearGradient(colors: [Color(red:0.4,green:0.2,blue:0.9), Color(red:0.2,green:0.05,blue:0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .active: return LinearGradient(colors: [.blue, Color(red:0.1,green:0.3,blue:0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .correct: return LinearGradient(colors: [.green, Color(red:0.1,green:0.6,blue:0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .wrong: return LinearGradient(colors: [.red, Color(red:0.7,green:0.1,blue:0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
            case .revealed: return LinearGradient(colors: [Color(.systemFill), Color(.systemFill)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        var border: Color {
            switch self { case .correct: return .green; case .wrong: return .red; default: return .clear }
        }
        var labelColor: Color {
            switch self { case .correct: return .green; case .wrong: return .red; default: return .secondary }
        }
    }

    private func displayState(for which: Which) -> BoxState {
        guard let sel = selected else {
            return (which == .A && phase == .playingA) || (which == .B && phase == .playingB) ? .active : .neutral
        }
        let isWinner = (which == .A && correctAnswer == .firstWider) ||
                       (which == .B && correctAnswer == .secondWider) ||
                       correctAnswer == .equal
        let userPicked = (which == .A && sel == .firstWider) || (which == .B && sel == .secondWider)
        if correctAnswer == .equal { return .correct }
        if which == .A && correctAnswer == .firstWider { return .correct }
        if which == .B && correctAnswer == .secondWider { return .correct }
        return .revealed
    }

    private func answerBg(_ a: ComparisonAnswer) -> Color {
        guard let sel = selected else { return Color(.systemBackground) }
        if a == correctAnswer { return Color.green.opacity(0.15) }
        if a == sel { return Color.red.opacity(0.15) }
        return Color(.systemBackground).opacity(0.5)
    }

    private func answerFg(_ a: ComparisonAnswer) -> Color {
        guard let sel = selected else { return .primary }
        if a == correctAnswer { return .green }
        if a == sel { return .red }
        return .secondary
    }

    // MARK: Logic

    private func newDrill() {
        let intervals = Interval.allCases.filter { $0 != .unison }
        intervalA = intervals.randomElement()!
        // 30% chance of equal intervals for the "equal" answer
        if Bool.random() && Bool.random() {
            intervalB = intervalA
        } else {
            intervalB = intervals.filter { $0 != intervalA }.randomElement()!
        }
        rootA = UInt8.random(in: 52...64)
        rootB = UInt8.random(in: 52...64)
        phase = .idle; selected = nil; drillStart = Date()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { playInterval(which: .A) }
    }

    private func playInterval(which: Which) {
        let interval = which == .A ? intervalA : intervalB
        let root = which == .A ? rootA : rootB
        phase = which == .A ? .playingA : .playingB

        AudioEngine.shared.playInterval(rootMidi: root, interval: interval, direction: .ascending)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            if which == .A {
                phase = .idle
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { playInterval(which: .B) }
            } else {
                phase = .ready
            }
        }
    }

    private func selectAnswer(_ answer: ComparisonAnswer) {
        guard selected == nil, phase == .ready else { return }
        let correct = answer == correctAnswer
        withAnimation(.spring(response: 0.3)) { selected = answer }
        score.total += 1
        if correct { score.correct += 1; HapticsManager.success() } else { HapticsManager.error() }
        let result = DrillResult(module: .intervalComparison,
                                  drillType: "compare_\(intervalA.name)_vs_\(intervalB.name)",
                                  wasCorrect: correct, responseTime: Date().timeIntervalSince(drillStart))
        modelContext.insert(result)
        if correct { userProfile.addXP(15) }
    }
}
