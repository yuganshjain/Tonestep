import SwiftUI
import SwiftData

struct NoteIdentificationModuleView: View {
    var body: some View {
        NavigationStack {
            NoteIDDrillView()
                .navigationTitle("Note Identification")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct NoteIDDrillView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userProfile: UserProfileStore

    @State private var targetMidi: UInt8 = 60
    @State private var selected: String?
    @State private var isPlaying = false
    @State private var score = (correct: 0, total: 0)
    @State private var playCount = 0
    @State private var drillStart = Date()

    // All 12 chromatic note names
    private let noteNames = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
    // Beginner range: C3–C5 (just natural notes)
    private let beginnerNotes: [UInt8] = [48,50,52,53,55,57,59,60,62,64,65,67,69,71,72]

    private var targetName: String {
        noteNames[Int(targetMidi) % 12]
    }
    private var targetOctave: Int { Int(targetMidi) / 12 - 1 }
    private var targetFullName: String { "\(targetName)\(targetOctave)" }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                scoreBar
                playCard
                if selected != nil { resultBanner }
                noteGrid
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
            Label("\(playCount) plays", systemImage: "speaker.wave.2.fill")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var playCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red:0.1,green:0.4,blue:0.9), Color(red:0.05,green:0.2,blue:0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                Image(systemName: isPlaying ? "waveform" : "music.note")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative, isActive: isPlaying)
            }

            Text(selected == nil ? "What note is this?" : "That was \(targetFullName)")
                .font(.headline)
                .foregroundStyle(selected == nil ? .primary : .secondary)

            Button { playNote() } label: {
                Label(isPlaying ? "Playing…" : (playCount == 0 ? "Play Note" : "Replay"), systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isPlaying ? Color.blue.opacity(0.5) : Color.blue)
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isPlaying || selected != nil)
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var resultBanner: some View {
        let correct = selected == targetName
        HStack(spacing: 10) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(correct ? .green : .red).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(correct ? "Correct! +15 XP" : "It was \(targetFullName)")
                    .font(.headline).foregroundStyle(correct ? .green : .red)
                Text(octaveContext)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background((selected == targetName ? Color.green : Color.red).opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .transition(.scale.combined(with: .opacity))
    }

    private var octaveContext: String {
        "\(targetName) is the \(targetOctave == 4 ? "middle octave" : "octave \(targetOctave)") reference pitch"
    }

    private var noteGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(noteNames, id: \.self) { name in
                NoteButton(
                    name: name,
                    state: buttonState(for: name),
                    isEnabled: selected == nil && playCount > 0
                ) { selectNote(name) }
            }
        }
    }

    private var nextButton: some View {
        Button { nextDrill() } label: {
            Text("Next Note")
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.blue).foregroundStyle(.white)
                .fontWeight(.semibold).clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Logic

    private func buttonState(for name: String) -> AnswerButtonState {
        guard let sel = selected else { return .idle }
        if name == targetName { return .correct }
        if name == sel { return .wrong }
        return .dimmed
    }

    private func playNote() {
        guard !isPlaying else { return }
        isPlaying = true
        playCount += 1
        AudioEngine.shared.playNote(midiNote: targetMidi, duration: 1.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { isPlaying = false }
    }

    private func selectNote(_ name: String) {
        guard selected == nil else { return }
        let correct = name == targetName
        HapticsManager.success()
        withAnimation(.spring(response: 0.3)) { selected = name }
        score.total += 1
        if correct { score.correct += 1 }

        let result = DrillResult(module: .noteIdentification,
                                 drillType: "note_\(targetName)",
                                 wasCorrect: correct,
                                 responseTime: Date().timeIntervalSince(drillStart))
        modelContext.insert(result)
        if correct { userProfile.addXP(15) }
    }

    private func nextDrill() {
        targetMidi = beginnerNotes.randomElement()!
        selected = nil
        isPlaying = false
        playCount = 0
        drillStart = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { playNote() }
    }
}

struct NoteButton: View {
    let name: String
    let state: AnswerButtonState
    let isEnabled: Bool
    let action: () -> Void

    private var isSharp: Bool { name.contains("#") }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(name)
                    .font(.system(size: isSharp ? 13 : 16, weight: .bold, design: .rounded))
                    .foregroundStyle(labelColor)
                if isSharp {
                    Text("black key")
                        .font(.system(size: 8))
                        .foregroundStyle(labelColor.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(border, lineWidth: state == .idle ? 1 : 0))
        }
        .disabled(!isEnabled)
        .buttonStyle(PressableButtonStyle())
        .animation(.spring(response: 0.2), value: state)
    }

    private var background: Color {
        switch state {
        case .idle:    return isSharp ? Color(.secondarySystemBackground) : Color(.systemBackground)
        case .correct: return Color.green.opacity(0.2)
        case .wrong:   return Color.red.opacity(0.2)
        case .dimmed:  return Color(.systemBackground).opacity(0.5)
        }
    }
    private var border: Color { state == .idle ? Color(.separator) : .clear }
    private var labelColor: Color {
        switch state { case .correct: return .green; case .wrong: return .red; case .dimmed: return .secondary; default: return .primary }
    }
}
