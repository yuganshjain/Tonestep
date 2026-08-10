import SwiftUI
import SwiftData

struct MelodyDictationView: View {
    var body: some View {
        NavigationStack {
            MelodyDrillView()
                .navigationTitle("Melody Dictation")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Drill State

private enum MelodyDrillPhase {
    case listening, answering, revealed
}

struct MelodyDrillView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userProfile: UserProfileStore

    @State private var targetMelody: [Int] = []
    @State private var userInput: [Int] = []
    @State private var phase: MelodyDrillPhase = .listening
    @State private var isPlaying = false
    @State private var score = (correct: 0, total: 0)
    @State private var showResult = false
    @State private var resultWasCorrect = false
    @State private var playCount = 0

    private let startTime = Date()

    // C major scale semitones from C4
    private let whiteKeys: [(semitone: Int, name: String)] = [
        (0,"C"), (2,"D"), (4,"E"), (5,"F"), (7,"G"), (9,"A"), (11,"B"), (12,"C′")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                scoreHeader
                melodyVisualization
                instructionBanner
                pianoKeyboard
                if phase == .answering { controlButtons }
                if showResult { resultBanner }
                if phase == .revealed { nextButton }
            }
            .padding()
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { generateMelody() }
    }

    // MARK: - Sub-views

    private var scoreHeader: some View {
        HStack {
            Label("\(score.correct)/\(score.total)", systemImage: "checkmark.circle.fill")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundStyle(.green)
            Spacer()
            Label("\(playCount) plays", systemImage: "speaker.wave.2.fill")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var melodyVisualization: some View {
        HStack(spacing: 8) {
            ForEach(0..<targetMelody.count, id: \.self) { i in
                let semitone = targetMelody[i]
                let noteName = whiteKeys.first(where: { $0.semitone == semitone })?.name ?? "?"

                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(noteColor(index: i))
                        .frame(height: 44)
                    if phase == .revealed {
                        Text(noteName)
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(.white)
                    } else if i < userInput.count {
                        let inputName = whiteKeys.first(where: { $0.semitone == userInput[i] })?.name ?? "?"
                        Text(inputName)
                            .font(.subheadline).fontWeight(.bold)
                            .foregroundStyle(.white)
                    } else {
                        Text("?")
                            .font(.title3).fontWeight(.bold)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(.spring(response: 0.3), value: phase)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func noteColor(index: Int) -> Color {
        guard phase == .revealed, index < userInput.count else {
            return index < userInput.count ? Color.purple.opacity(0.7) : Color(.systemFill)
        }
        return userInput[index] == targetMelody[index] ? Color.green : Color.red
    }

    private var instructionBanner: some View {
        Group {
            switch phase {
            case .listening:
                HStack(spacing: 10) {
                    Image(systemName: isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2")
                        .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                        .foregroundStyle(.purple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isPlaying ? "Listen carefully…" : "Tap play to hear the melody")
                            .font(.subheadline).fontWeight(.semibold)
                        Text("You can replay as many times as you need")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        playMelody()
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .font(.subheadline).fontWeight(.semibold)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(isPlaying ? Color.purple.opacity(0.3) : Color.purple)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .disabled(isPlaying)
                }
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 14))

            case .answering:
                HStack(spacing: 10) {
                    Image(systemName: "pianokeys").foregroundStyle(.purple)
                    Text("Tap the notes you heard in order")
                        .font(.subheadline).fontWeight(.semibold)
                    Spacer()
                    Button("Replay") { playMelody() }
                        .font(.caption).foregroundStyle(.purple)
                }
                .padding(14)
                .background(.background, in: RoundedRectangle(cornerRadius: 14))

            case .revealed:
                EmptyView()
            }
        }
    }

    private var pianoKeyboard: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let keyW = (geo.size.width - 14) / 8
                ZStack(alignment: .topLeading) {
                    // White keys
                    HStack(spacing: 2) {
                        ForEach(whiteKeys, id: \.semitone) { key in
                            PianoWhiteKey(
                                name: key.name,
                                state: keyState(semitone: key.semitone),
                                width: keyW,
                                enabled: phase == .answering
                            ) {
                                tapNote(semitone: key.semitone)
                            }
                        }
                    }

                    // Black keys overlay
                    HStack(spacing: 0) {
                        blackKeyGap(keyW, hasBlack: false)
                        blackKey(semitone: 1,  name: "C#", keyW: keyW)
                        blackKey(semitone: 3,  name: "D#", keyW: keyW)
                        blackKeyGap(keyW, hasBlack: false)
                        blackKey(semitone: 6,  name: "F#", keyW: keyW)
                        blackKey(semitone: 8,  name: "G#", keyW: keyW)
                        blackKey(semitone: 10, name: "A#", keyW: keyW)
                        Spacer()
                    }
                }
            }
            .frame(height: 120)
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func blackKey(semitone: Int, name: String, keyW: CGFloat) -> some View {
        let bw = keyW * 0.65
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(phase == .revealed && targetMelody.contains(semitone)
                      ? (userInput.contains(semitone) ? Color.green : Color.red)
                      : (userInput.contains(semitone) ? Color.purple : Color.black))
                .frame(width: bw, height: 76)
            if phase != .listening {
                Text(name).font(.system(size: 8)).foregroundStyle(.white).offset(y: 28)
            }
        }
        .frame(width: keyW, height: 76, alignment: .top)
        .offset(x: -keyW * 0.5)
    }

    private func blackKeyGap(_ keyW: CGFloat, hasBlack: Bool) -> some View {
        Spacer().frame(width: hasBlack ? keyW : keyW * 0.5)
    }

    private var controlButtons: some View {
        HStack(spacing: 12) {
            Button {
                if !userInput.isEmpty { userInput.removeLast() }
            } label: {
                Label("Undo", systemImage: "delete.backward")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.primary)
            }
            .disabled(userInput.isEmpty)

            Button {
                submitAnswer()
            } label: {
                Text("Check")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(userInput.count == targetMelody.count ? Color.purple : Color.purple.opacity(0.4))
                    .foregroundStyle(.white)
                    .fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(userInput.count != targetMelody.count)
        }
    }

    private var resultBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: resultWasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(resultWasCorrect ? .green : .red)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(resultWasCorrect ? "Correct!" : "Not quite")
                    .font(.headline)
                    .foregroundStyle(resultWasCorrect ? .green : .red)
                Text(resultWasCorrect ? "+20 XP" : "See the correct notes above in green")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(
            (resultWasCorrect ? Color.green : Color.red).opacity(0.1),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var nextButton: some View {
        Button { nextDrill() } label: {
            Text("Next Melody")
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

    private func keyState(semitone: Int) -> PianoKeyState {
        switch phase {
        case .listening:
            return .idle
        case .answering:
            if userInput.contains(semitone) { return .selected }
            return .idle
        case .revealed:
            if targetMelody.contains(semitone) && userInput.contains(semitone) { return .correct }
            if targetMelody.contains(semitone) { return .correct }
            if userInput.contains(semitone) { return .wrong }
            return .idle
        }
    }

    private func tapNote(semitone: Int) {
        guard phase == .answering, userInput.count < targetMelody.count else { return }
        AudioEngine.shared.playNote(midiNote: UInt8(clamping: 60 + semitone), duration: 0.4)
        HapticsManager.impact()
        withAnimation(.spring(response: 0.2)) {
            userInput.append(semitone)
        }
    }

    private func generateMelody() {
        let pentatonic = [0, 2, 4, 7, 9]
        let length = userProfile.xp < 200 ? 3 : (userProfile.xp < 600 ? 4 : 5)
        var melody: [Int] = []
        for _ in 0..<length {
            melody.append(pentatonic.randomElement()!)
        }
        targetMelody = melody
        userInput = []
        phase = .listening
        isPlaying = false
        showResult = false
        playCount = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { playMelody() }
    }

    private func playMelody() {
        guard !isPlaying else { return }
        isPlaying = true
        playCount += 1
        let notes = targetMelody.map { UInt8(clamping: 60 + $0) }
        AudioEngine.shared.playMelody(midiNotes: notes, tempo: 0.55)
        let totalTime = Double(notes.count) * 0.55 + 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTime) {
            isPlaying = false
            if phase == .listening { phase = .answering }
        }
    }

    private func submitAnswer() {
        let correct = userInput == targetMelody
        resultWasCorrect = correct
        phase = .revealed
        score.total += 1
        if correct { score.correct += 1 }

        correct ? HapticsManager.success() : HapticsManager.error()
        withAnimation(.spring(response: 0.3)) { showResult = true }

        let result = DrillResult(module: .melodicDictation,
                                 drillType: "melody_\(targetMelody.count)_notes",
                                 wasCorrect: correct,
                                 responseTime: Date().timeIntervalSince(startTime))
        modelContext.insert(result)
        DrillRecorder.grade(result, context: modelContext)
        if correct { userProfile.addXP(20) }
    }

    private func nextDrill() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showResult = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { generateMelody() }
    }
}

// MARK: - Piano Key Components

enum PianoKeyState { case idle, selected, correct, wrong }

struct PianoWhiteKey: View {
    let name: String
    let state: PianoKeyState
    let width: CGFloat
    let enabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(keyFill)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.gray.opacity(0.3), lineWidth: 1))
                Text(name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(state == .idle || state == .selected ? Color.secondary : .white)
                    .padding(.bottom, 6)
            }
        }
        .frame(width: width, height: 120)
        .disabled(!enabled)
        .buttonStyle(PressableButtonStyle())
    }

    private var keyFill: Color {
        switch state {
        case .idle:     return .white
        case .selected: return Color.purple.opacity(0.8)
        case .correct:  return .green
        case .wrong:    return .red
        }
    }
}
