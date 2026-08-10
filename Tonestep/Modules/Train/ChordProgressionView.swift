import SwiftUI
import SwiftData

struct ChordProgressionModuleView: View {
    var body: some View {
        NavigationStack {
            ChordProgressionDrillView()
                .navigationTitle("Chord Progressions")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ChordProgressionDrillView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userProfile: UserProfileStore

    @State private var current: ChordProgression = ChordProgression.all[0]
    @State private var options: [ChordProgression] = []
    @State private var selected: ChordProgression?
    @State private var isPlaying = false
    @State private var rootMidi: UInt8 = 60
    @State private var score = (correct: 0, total: 0)
    @State private var drillStart = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                scoreBar
                playCard
                if let selected { resultDisplay(selected) }
                if !options.isEmpty { answersGrid }
                if selected != nil { nextButton }
            }
            .padding()
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { nextDrill() }
    }

    // MARK: - Sub-views

    private var scoreBar: some View {
        HStack {
            Label("\(score.correct)/\(score.total)", systemImage: "checkmark.circle.fill")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.green)
            Spacer()
            Text("Chord Progressions").font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var playCard: some View {
        VStack(spacing: 16) {
            // Roman numeral visualization
            HStack(spacing: 0) {
                ForEach(current.romanNumerals, id: \.self) { numeral in
                    VStack(spacing: 4) {
                        Text(numeral)
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)

            // Play button
            Button {
                playProgression()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isPlaying ? "waveform" : "play.fill")
                        .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                        .font(.title2)
                    Text(isPlaying ? "Playing…" : "Play Progression")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
            }
            .disabled(isPlaying || selected != nil)
        }
        .padding(20)
        .background(
            LinearGradient(colors: [Color(red:0.35,green:0.1,blue:0.8), Color(red:0.55,green:0.05,blue:0.65)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20)
        )
    }

    private var answersGrid: some View {
        VStack(spacing: 10) {
            Text("Which progression did you hear?")
                .font(.subheadline).foregroundStyle(.secondary)
            ForEach(options) { option in
                ProgressionAnswerButton(
                    progression: option,
                    state: buttonState(for: option),
                    isEnabled: selected == nil
                ) {
                    selectAnswer(option)
                }
            }
        }
    }

    @ViewBuilder
    private func resultDisplay(_ picked: ChordProgression) -> some View {
        let correct = picked.id == current.id
        HStack(spacing: 10) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(correct ? .green : .red)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(correct ? "Correct! +15 XP" : "That was \(current.name)")
                    .font(.headline)
                    .foregroundStyle(correct ? .green : .red)
                Text(current.description)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background((correct ? Color.green : Color.red).opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var nextButton: some View {
        Button { nextDrill() } label: {
            Text("Next Progression")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.purple)
                .foregroundStyle(.white)
                .fontWeight(.semibold)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Logic

    private func buttonState(for option: ChordProgression) -> AnswerButtonState {
        guard let sel = selected else { return .idle }
        if option.id == current.id { return .correct }
        if option.id == sel.id { return .wrong }
        return .dimmed
    }

    private func playProgression() {
        isPlaying = true
        let root = UInt8(clamping: 48 + Int.random(in: 0...7))
        rootMidi = root
        AudioEngine.shared.playChordProgression(current, rootMidi: root, tempo: 1.0)
        let totalTime = Double(current.rootOffsets.count) * 1.0 + 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTime) { isPlaying = false }
    }

    private func selectAnswer(_ option: ChordProgression) {
        guard selected == nil else { return }
        let correct = option.id == current.id
        correct ? HapticsManager.success() : HapticsManager.error()
        withAnimation(.spring(response: 0.3)) { selected = option }
        score.total += 1
        if correct { score.correct += 1 }

        let result = DrillResult(module: .chordProgressions,
                                 drillType: "progression_\(current.id)",
                                 wasCorrect: correct,
                                 responseTime: Date().timeIntervalSince(drillStart))
        modelContext.insert(result)
        DrillRecorder.grade(result, context: modelContext)
        if correct { userProfile.addXP(15) }
    }

    private func nextDrill() {
        current = ChordProgression.all.randomElement()!
        var pool = ChordProgression.all.filter { $0.id != current.id }.shuffled()
        options = ([current] + Array(pool.prefix(3))).shuffled()
        selected = nil
        isPlaying = false
        drillStart = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { playProgression() }
    }
}

// MARK: - Answer Button

struct ProgressionAnswerButton: View {
    let progression: ChordProgression
    let state: AnswerButtonState
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(progression.name)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(foreground)
                    Text(progression.genre)
                        .font(.caption).foregroundStyle(foreground.opacity(0.7))
                }
                Spacer()
                if state == .correct {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else if state == .wrong {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                }
            }
            .padding(14)
            .background(background, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(border, lineWidth: state == .idle ? 1 : 0))
        }
        .disabled(!isEnabled)
        .buttonStyle(PressableButtonStyle())
        .animation(.spring(response: 0.25), value: state)
    }

    private var background: Color {
        switch state {
        case .idle:    return Color(.systemBackground)
        case .correct: return Color.green.opacity(0.15)
        case .wrong:   return Color.red.opacity(0.15)
        case .dimmed:  return Color(.systemBackground).opacity(0.5)
        }
    }
    private var border: Color {
        switch state {
        case .idle:    return Color(.separator)
        default:       return .clear
        }
    }
    private var foreground: Color {
        switch state {
        case .correct: return .green
        case .wrong:   return .red
        case .dimmed:  return .secondary
        default:       return .primary
        }
    }
}
