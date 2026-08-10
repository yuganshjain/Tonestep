import SwiftUI
import SwiftData

struct RhythmTrainerModuleView: View {
    var body: some View {
        NavigationStack {
            RhythmDrillView()
                .navigationTitle("Rhythm Trainer")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

private enum RhythmPhase { case listening, watching, tapping, revealed }

struct RhythmDrillView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userProfile: UserProfileStore

    @State private var pattern: RhythmPattern = RhythmPattern.beginner[0]
    @State private var options: [RhythmPattern] = []
    @State private var selected: RhythmPattern?
    @State private var phase: RhythmPhase = .listening
    @State private var isPlaying = false
    @State private var highlightedBeat = -1
    @State private var score = (correct: 0, total: 0)
    @State private var drillStart = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                scoreBar
                beatVisualizer
                phaseInstructions
                if phase == .revealed || phase == .watching || phase == .listening {
                    answersGrid
                }
                if selected != nil { nextButton }
            }
            .padding()
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { nextDrill() }
    }

    // MARK: - Score

    private var scoreBar: some View {
        HStack {
            Label("\(score.correct)/\(score.total)", systemImage: "checkmark.circle.fill")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.green)
            Spacer()
            Text("Rhythm Trainer").font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Beat Visualizer

    private var beatVisualizer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(0..<pattern.beats.count, id: \.self) { i in
                    BeatCell(
                        beat: pattern.beats[i],
                        isActive: i == highlightedBeat,
                        isRevealed: phase == .revealed
                    )
                }
            }

            // Play button
            Button { listenToPattern() } label: {
                HStack(spacing: 8) {
                    Image(systemName: isPlaying ? "waveform" : "play.fill")
                        .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                    Text(isPlaying ? "Playing…" : (phase == .listening ? "Hear the rhythm" : "Replay"))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isPlaying ? Color.orange.opacity(0.6) : Color.orange)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isPlaying)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var phaseInstructions: some View {
        switch phase {
        case .listening:
            InfoBanner(icon: "ear.fill", color: .orange,
                       title: "Listen to the pattern",
                       subtitle: "Then choose which rhythm matches what you heard")
        case .watching, .tapping:
            EmptyView()
        case .revealed:
            if let sel = selected {
                let correct = sel.id == pattern.id
                ResultBanner(isCorrect: correct, correctName: pattern.name)
            }
        }
    }

    private var answersGrid: some View {
        VStack(spacing: 10) {
            if phase != .listening {
                Text("Which rhythm did you hear?")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(options) { opt in
                RhythmOptionButton(
                    pattern: opt,
                    state: buttonState(for: opt),
                    isEnabled: selected == nil && phase != .listening
                ) { selectAnswer(opt) }
            }
        }
    }

    private var nextButton: some View {
        Button { nextDrill() } label: {
            Text("Next Pattern")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.orange)
                .foregroundStyle(.white)
                .fontWeight(.semibold)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Logic

    private func buttonState(for opt: RhythmPattern) -> AnswerButtonState {
        guard let sel = selected else { return .idle }
        if opt.id == pattern.id { return .correct }
        if opt.id == sel.id     { return .wrong }
        return .dimmed
    }

    private func listenToPattern() {
        guard !isPlaying else { return }
        isPlaying = true
        if phase == .listening { phase = .watching }

        var offset = 0.0
        let baseTime = 60.0 / Double(pattern.bpm)
        for (i, beat) in pattern.beats.enumerated() {
            let t = offset
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                highlightedBeat = i
            }
            offset += beat.duration * baseTime * 2
        }

        AudioEngine.shared.playRhythmPattern(pattern) {
            DispatchQueue.main.async {
                highlightedBeat = -1
                isPlaying = false
            }
        }
    }

    private func selectAnswer(_ opt: RhythmPattern) {
        guard selected == nil else { return }
        let correct = opt.id == pattern.id
        correct ? HapticsManager.success() : HapticsManager.error()
        withAnimation(.spring(response: 0.3)) {
            selected = opt
            phase = .revealed
        }
        score.total += 1
        if correct { score.correct += 1 }

        let result = DrillResult(module: .rhythmTrainer,
                                 drillType: "rhythm_\(pattern.id)",
                                 wasCorrect: correct,
                                 responseTime: Date().timeIntervalSince(drillStart))
        modelContext.insert(result)
        DrillRecorder.grade(result, context: modelContext)
        if correct { userProfile.addXP(12) }
    }

    private func nextDrill() {
        let allPatterns = RhythmPattern.beginner + RhythmPattern.intermediate
        pattern = allPatterns.randomElement()!
        var pool = allPatterns.filter { $0.id != pattern.id }.shuffled()
        options = ([pattern] + Array(pool.prefix(3))).shuffled()
        selected = nil
        phase = .listening
        isPlaying = false
        highlightedBeat = -1
        drillStart = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { listenToPattern() }
    }
}

// MARK: - Beat Cell

struct BeatCell: View {
    let beat: RhythmPattern.RhythmBeat
    let isActive: Bool
    let isRevealed: Bool

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(beat.isRest ? Color(.systemFill) : (isActive ? Color.orange : Color.orange.opacity(0.35)))
                .frame(height: 44)
                .overlay(
                    Text(beat.symbol)
                        .font(.system(size: 18))
                        .opacity(isRevealed ? 1 : (isActive ? 1 : 0.4))
                )
                .scaleEffect(isActive ? 1.1 : 1.0)
                .animation(.spring(response: 0.15), value: isActive)
            Text(beatLabel)
                .font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var beatLabel: String {
        switch beat {
        case .quarter: return "1"
        case .eighth:  return "½"
        case .half:    return "2"
        case .sixteenth: return "¼"
        case .rest:    return "—"
        }
    }
}

// MARK: - Rhythm Option Button

struct RhythmOptionButton: View {
    let pattern: RhythmPattern
    let state: AnswerButtonState
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    ForEach(0..<pattern.beats.count, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(pattern.beats[i].isRest ? Color(.systemFill) : miniColor)
                            .frame(width: CGFloat(pattern.beats[i].duration) * 20, height: 20)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(pattern.name).font(.caption).fontWeight(.semibold).foregroundStyle(foreground)
                    Text("\(pattern.bpm) BPM").font(.caption2).foregroundStyle(.secondary)
                }
                if state == .correct { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                if state == .wrong   { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) }
            }
            .padding(12)
            .background(background, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(border, lineWidth: state == .idle ? 1 : 0))
        }
        .disabled(!isEnabled)
        .buttonStyle(PressableButtonStyle())
        .animation(.spring(response: 0.25), value: state)
    }

    private var miniColor: Color { state == .correct ? .green : state == .wrong ? .red : .orange }
    private var background: Color {
        switch state {
        case .idle: return Color(.systemBackground)
        case .correct: return Color.green.opacity(0.12)
        case .wrong: return Color.red.opacity(0.12)
        case .dimmed: return Color(.systemBackground).opacity(0.5)
        }
    }
    private var border: Color { state == .idle ? Color(.separator) : .clear }
    private var foreground: Color {
        switch state {
        case .correct: return .green; case .wrong: return .red; case .dimmed: return .secondary; default: return .primary
        }
    }
}

// MARK: - Shared Banners

struct InfoBanner: View {
    let icon: String; let color: Color; let title: String; let subtitle: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct ResultBanner: View {
    let isCorrect: Bool; let correctName: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(isCorrect ? .green : .red).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(isCorrect ? "Correct! +12 XP" : "That was: \(correctName)")
                    .font(.headline).foregroundStyle(isCorrect ? .green : .red)
                Text(isCorrect ? "Great ear!" : "Keep practicing!")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background((isCorrect ? Color.green : Color.red).opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
