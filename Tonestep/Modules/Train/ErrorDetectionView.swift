import SwiftUI
import SwiftData

struct ErrorDetectionModuleView: View {
    var body: some View {
        NavigationStack {
            ErrorDetectionDrillView()
                .navigationTitle("Error Detection")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Phase

private enum ErrorPhase {
    case idle, playingOriginal, waitingForModified, playingModified, answering, revealed
}

struct ErrorDetectionDrillView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userProfile: UserProfileStore

    @State private var melody: [UInt8] = []
    @State private var errorBeat: Int = 0       // 0-indexed
    @State private var phase: ErrorPhase = .idle
    @State private var selected: Int?            // 0-indexed beat user picked
    @State private var score = (correct: 0, total: 0)
    @State private var drillStart = Date()
    @State private var highlightedBeat: Int? = nil

    private let beatCount = 4
    // Pentatonic notes for easy melody construction
    private let pool: [UInt8] = [60, 62, 64, 67, 69, 72, 74, 76]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                scoreAndInstruction
                beatVisualizer
                playControls
                if phase == .answering || phase == .revealed {
                    beatButtons
                }
                if phase == .revealed {
                    resultCard
                    nextButton
                }
            }
            .padding()
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { newDrill() }
    }

    // MARK: Sub-views

    private var scoreAndInstruction: some View {
        VStack(spacing: 10) {
            HStack {
                Label("\(score.correct)/\(score.total)", systemImage: "checkmark.circle.fill")
                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(.green)
                Spacer()
                Text("+25 XP per correct").font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))

            // Phase instruction
            Text(phaseText)
                .font(.headline).multilineTextAlignment(.center)
                .frame(maxWidth: .infinity).padding(14)
                .background(phaseColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(phaseColor)
                .animation(.easeInOut(duration: 0.3), value: phase)
        }
    }

    private var beatVisualizer: some View {
        HStack(spacing: 10) {
            ForEach(0..<beatCount, id: \.self) { i in
                VStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(beatBg(i))
                            .frame(height: 70)
                        Image(systemName: "music.quarternote.3")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(beatFg(i))
                            .scaleEffect(highlightedBeat == i ? 1.3 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: highlightedBeat)
                    }
                    Text("Beat \(i + 1)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private var playControls: some View {
        VStack(spacing: 12) {
            Button { playOriginal() } label: {
                Label(
                    phase == .playingOriginal ? "Playing Original…" : "▶ Play Original Melody",
                    systemImage: phase == .playingOriginal ? "waveform" : "play.fill"
                )
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(phase == .playingOriginal ? Color.blue.opacity(0.5) : Color.blue)
                .foregroundStyle(.white).fontWeight(.semibold)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(phase == .playingOriginal || phase == .playingModified)
            .buttonStyle(PressableButtonStyle())

            if phase == .waitingForModified || phase == .playingModified || phase == .answering || phase == .revealed {
                Button { playModified() } label: {
                    Label(
                        phase == .playingModified ? "Playing Modified…" : "▶ Play Modified Melody",
                        systemImage: phase == .playingModified ? "waveform" : "play.fill"
                    )
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(phase == .playingModified ? Color.red.opacity(0.5) : Color(red:0.7,green:0.1,blue:0.1))
                    .foregroundStyle(.white).fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(phase == .playingOriginal || phase == .playingModified)
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private var beatButtons: some View {
        VStack(spacing: 10) {
            Text("Which beat was different?").font(.headline)
            HStack(spacing: 10) {
                ForEach(0..<beatCount, id: \.self) { i in
                    Button { selectBeat(i) } label: {
                        VStack(spacing: 4) {
                            Text("\(i + 1)")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                            Text("Beat").font(.system(size: 10))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(selectBtnBg(i), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(selectBtnFg(i))
                    }
                    .disabled(phase == .revealed)
                    .buttonStyle(PressableButtonStyle())
                    .animation(.spring(response: 0.25), value: selected)
                }
            }
        }
    }

    @ViewBuilder
    private var resultCard: some View {
        let correct = selected == errorBeat
        HStack(spacing: 12) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2).foregroundStyle(correct ? .green : .red)
            VStack(alignment: .leading, spacing: 3) {
                Text(correct ? "Correct! +25 XP" : "It was Beat \(errorBeat + 1)")
                    .fontWeight(.bold).foregroundStyle(correct ? .green : .red)
                Text(correct ? "Your ear caught the difference!" : "Listen to the modified melody again to hear it")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background((correct ? Color.green : Color.red).opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var nextButton: some View {
        Button { newDrill() } label: {
            Text("Next Melody").frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color(red:0.8,green:0.2,blue:0.2)).foregroundStyle(.white)
                .fontWeight(.semibold).clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: Appearance helpers

    private var phaseText: String {
        switch phase {
        case .idle:             return "Tap ▶ to hear the original melody"
        case .playingOriginal:  return "Listen carefully to the original melody"
        case .waitingForModified: return "Now play the modified version — one note is wrong"
        case .playingModified:  return "One note has been changed — which beat?"
        case .answering:        return "Which beat has the wrong note?"
        case .revealed:         return selected == errorBeat ? "Correct!" : "Not quite — the error was on Beat \(errorBeat + 1)"
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .playingOriginal: return .blue
        case .playingModified: return .red
        case .revealed:        return selected == errorBeat ? .green : .red
        default:               return .purple
        }
    }

    private func beatBg(_ i: Int) -> Color {
        if highlightedBeat == i { return Color.purple.opacity(0.6) }
        if phase == .revealed {
            if i == errorBeat { return Color.red.opacity(0.25) }
            if i == selected && selected != errorBeat { return Color.red.opacity(0.1) }
        }
        return Color(.systemFill)
    }

    private func beatFg(_ i: Int) -> Color {
        if highlightedBeat == i { return .white }
        if phase == .revealed && i == errorBeat { return .red }
        return .secondary
    }

    private func selectBtnBg(_ i: Int) -> Color {
        guard let sel = selected else { return Color(.systemBackground) }
        if phase == .revealed {
            if i == errorBeat { return Color.green.opacity(0.2) }
            if i == sel { return Color.red.opacity(0.2) }
        }
        if i == sel { return Color.purple.opacity(0.15) }
        return Color(.systemBackground)
    }

    private func selectBtnFg(_ i: Int) -> Color {
        guard let sel = selected else { return .primary }
        if phase == .revealed {
            if i == errorBeat { return .green }
            if i == sel { return .red }
        }
        return .primary
    }

    // MARK: Logic

    private func newDrill() {
        melody = (0..<beatCount).map { _ in pool.randomElement()! }
        errorBeat = Int.random(in: 0..<beatCount)
        phase = .idle; selected = nil; highlightedBeat = nil; drillStart = Date()
    }

    private func playOriginal() {
        phase = .playingOriginal
        playMelody(melody: melody) {
            phase = .waitingForModified
        }
    }

    private func playModified() {
        phase = .playingModified
        var modified = melody
        // Change the error beat by ±2 semitones (keeping in a different pitch class)
        let current = Int(melody[errorBeat])
        let change = Bool.random() ? 2 : -2
        modified[errorBeat] = UInt8(clamping: current + change)
        playMelody(melody: modified) {
            phase = .answering
        }
    }

    private func playMelody(melody: [UInt8], tempo: TimeInterval = 0.55, completion: @escaping () -> Void) {
        for (i, note) in melody.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * tempo) {
                highlightedBeat = i
                AudioEngine.shared.playNote(midiNote: note, velocity: 82, duration: tempo * 1.4)
            }
        }
        let total = Double(melody.count) * tempo + 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            highlightedBeat = nil
            completion()
        }
    }

    private func selectBeat(_ beat: Int) {
        guard selected == nil, phase == .answering else { return }
        selected = beat
        let correct = beat == errorBeat
        withAnimation(.spring(response: 0.3)) { phase = .revealed }
        score.total += 1
        if correct { score.correct += 1; HapticsManager.success() } else { HapticsManager.error() }
        let result = DrillResult(module: .errorDetection, drillType: "error_beat\(errorBeat + 1)",
                                  wasCorrect: correct, responseTime: Date().timeIntervalSince(drillStart))
        modelContext.insert(result)
        DrillRecorder.grade(result, context: modelContext)
        if correct { userProfile.addXP(25) }
    }
}
