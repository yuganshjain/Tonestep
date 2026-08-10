import SwiftUI
import SwiftData

struct JazzChordsModuleView: View {
    var body: some View {
        JazzChordsDrillView()
            .navigationTitle("Jazz Chords")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Model

private struct JazzChord: Identifiable {
    let id = UUID()
    let name: String
    let short: String
    let semitones: [Int]
    let color: Color
}

private enum JCPhase { case idle, playing, answering, revealed }

// MARK: - Drill View

struct JazzChordsDrillView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userProfile: UserProfileStore

    @State private var target: JazzChord?
    @State private var root = 60
    @State private var phase: JCPhase = .idle
    @State private var selected: String? = nil
    @State private var drillStart = Date()
    @State private var score = (correct: 0, total: 0)

    private let chords: [JazzChord] = [
        JazzChord(name: "Major 7th",       short: "Maj7", semitones: [0, 4, 7, 11], color: Color(red: 0.2, green: 0.5, blue: 0.9)),
        JazzChord(name: "Minor 7th",       short: "m7",   semitones: [0, 3, 7, 10], color: Color(red: 0.5, green: 0.2, blue: 0.9)),
        JazzChord(name: "Dominant 7th",    short: "7",    semitones: [0, 4, 7, 10], color: Color(red: 0.9, green: 0.45, blue: 0.1)),
        JazzChord(name: "Half Diminished", short: "ø7",   semitones: [0, 3, 6, 10], color: Color(red: 0.1, green: 0.65, blue: 0.5)),
        JazzChord(name: "Diminished 7th",  short: "dim7", semitones: [0, 3, 6, 9],  color: Color(red: 0.8, green: 0.15, blue: 0.3)),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                scoreBar
                chordDisplay
                replayButton
                answerGrid
                if phase == .revealed { nextButton }
                Spacer(minLength: 40)
            }
            .padding()
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { nextChord() }
    }

    // MARK: Score bar

    private var scoreBar: some View {
        HStack {
            Text("Jazz Chords").font(.headline)
            Spacer()
            Text("\(score.correct)/\(score.total)")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(score.total == 0 ? AnyShapeStyle(.secondary) : (Double(score.correct)/Double(score.total) >= 0.7 ? AnyShapeStyle(Color.green) : AnyShapeStyle(Color.orange)))
        }
        .padding(.horizontal, 4)
    }

    // MARK: Chord display

    private var chordDisplay: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: phase == .idle ? [Color.gray.opacity(0.3), Color.gray.opacity(0.2)] :
                                    [target?.color ?? .purple, (target?.color ?? .purple).opacity(0.6)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 130, height: 130)
                    .animation(.spring(response: 0.4), value: phase)

                if phase == .revealed, let t = target {
                    VStack(spacing: 4) {
                        Text(t.short)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(t.name)
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Image(systemName: phase == .idle ? "music.quarternote.3" : "speaker.wave.3.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: phase == .playing)
                }
            }

            Text(phase == .idle ? "Tap play to hear the chord" :
                 phase == .playing ? "Listen…" :
                 phase == .answering ? "Which 7th chord is this?" : "")
                .font(.subheadline).foregroundStyle(.secondary)
                .animation(.easeInOut, value: phase)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: Replay

    private var replayButton: some View {
        Button {
            guard phase != .idle else { return }
            playChord()
        } label: {
            Label("Replay Chord", systemImage: "speaker.wave.2.fill")
                .font(.subheadline).fontWeight(.medium)
                .padding(.horizontal, 20).padding(.vertical, 11)
                .background(Color.purple.opacity(phase == .idle ? 0.06 : 0.12))
                .foregroundStyle(phase == .idle ? Color.secondary : Color.purple)
                .clipShape(Capsule())
        }
        .disabled(phase == .idle)
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: Answer grid

    private var answerGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(chords) { chord in
                answerButton(for: chord)
            }
        }
    }

    private func answerButton(for chord: JazzChord) -> some View {
        let state = buttonState(for: chord)
        return Button {
            guard phase == .answering else { return }
            submitAnswer(chord)
        } label: {
            VStack(spacing: 4) {
                Text(chord.short)
                    .font(.title3).fontWeight(.black)
                    .foregroundStyle(state == .idle ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.white))
                Text(chord.name)
                    .font(.caption2).fontWeight(.medium)
                    .foregroundStyle(state == .idle ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.white.opacity(0.85)))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(buttonBackground(state, chord: chord), in: RoundedRectangle(cornerRadius: 16))
        }
        .disabled(phase != .answering)
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: Next button

    private var nextButton: some View {
        Button { nextChord() } label: {
            Text("Next Chord →")
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.purple).foregroundStyle(.white)
                .fontWeight(.semibold).clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: State helpers

    private enum BtnState { case idle, correct, wrong, dimmed }

    private func buttonState(for chord: JazzChord) -> BtnState {
        guard phase == .revealed, let sel = selected, let t = target else { return .idle }
        if chord.name == t.name { return .correct }
        if chord.name == sel { return .wrong }
        return .dimmed
    }

    private func buttonBackground(_ state: BtnState, chord: JazzChord) -> Color {
        switch state {
        case .idle:    return Color(.secondarySystemBackground)
        case .correct: return .green
        case .wrong:   return .red
        case .dimmed:  return Color(.systemFill)
        }
    }

    // MARK: Logic

    private func nextChord() {
        target = chords.randomElement()
        root = Int.random(in: 55...67)
        selected = nil
        phase = .playing
        drillStart = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { playChord() }
    }

    private func playChord() {
        guard let t = target else { return }
        // Arpeggiate slightly for a jazz feel
        for (i, semitone) in t.semitones.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) {
                AudioEngine.shared.playNote(midiNote: UInt8(root + semitone), duration: 2.0)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            if phase == .playing { withAnimation { phase = .answering } }
        }
    }

    private func submitAnswer(_ chord: JazzChord) {
        guard let t = target, phase == .answering else { return }
        selected = chord.name
        phase = .revealed
        score.total += 1
        let correct = chord.name == t.name
        if correct {
            score.correct += 1
            HapticsManager.success()
            userProfile.addXP(15)
        } else {
            HapticsManager.error()
        }
        let result = DrillResult(
            module: .jazzChords,
            drillType: "jazz_\(t.name.lowercased().replacingOccurrences(of: " ", with: "_"))",
            wasCorrect: correct,
            responseTime: Date().timeIntervalSince(drillStart)
        )
        modelContext.insert(result)
        DrillRecorder.grade(result, context: modelContext)
    }
}
