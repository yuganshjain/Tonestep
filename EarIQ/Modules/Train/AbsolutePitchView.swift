import SwiftUI

struct AbsolutePitchModuleView: View {
    var body: some View {
        NavigationStack {
            AbsolutePitchDrillView()
                .navigationTitle("Absolute Pitch")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

private let chromaticNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

private enum APPhase { case idle, playing, answering, revealed }
private enum APBtnState { case idle, correct, wrong, dimmed }

struct AbsolutePitchDrillView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userProfile: UserProfileStore

    @State private var targetMidi: Int = 60
    @State private var phase: APPhase = .idle
    @State private var selectedChroma: Int? = nil
    @State private var score = (correct: 0, total: 0)
    @State private var sessionStart = Date()
    @State private var naturalOnly = true

    // C3–B4 (two octaves) — more musically useful than just one
    private let notePool = Array(48...71)

    private var displayedNotes: [Int] {
        naturalOnly
            ? [0, 2, 4, 5, 7, 9, 11]   // C D E F G A B
            : Array(0...11)              // all 12 chromatic
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                targetDisplay
                difficultyToggle
                noteGrid
                actionButton
                if phase == .revealed { feedbackCard }
                Spacer()
            }
            .padding()
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { newDrill() }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack {
            Label("\(score.correct)/\(score.total)", systemImage: "checkmark.circle.fill")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.green)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("No reference tone").font(.caption).foregroundStyle(.secondary)
                Text("Name the note you hear").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Target Display

    private var targetDisplay: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.7, green: 0.5, blue: 0.1), Color(red: 0.55, green: 0.35, blue: 0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)

                VStack(spacing: 4) {
                    switch phase {
                    case .idle:
                        Image(systemName: "star.fill")
                            .font(.system(size: 36)).foregroundStyle(.white)
                    case .playing:
                        ProgressView().tint(.white).scaleEffect(1.3)
                        Text("Listen...").font(.caption).foregroundStyle(.white.opacity(0.8))
                    case .answering, .revealed:
                        Text("Name it").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        Text("Octave doesn't matter").font(.caption2).foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .scaleEffect(phase == .playing ? 1.04 : 1.0)
            .animation(.spring(response: 0.4), value: phase == .playing)

            if phase == .answering || phase == .revealed {
                Button { replayNote() } label: {
                    Label("Replay Note", systemImage: "speaker.wave.2.fill")
                        .font(.caption).fontWeight(.medium)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color(red: 0.7, green: 0.5, blue: 0.1).opacity(0.12))
                        .foregroundStyle(Color(red: 0.55, green: 0.35, blue: 0.05))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Difficulty Toggle

    private var difficultyToggle: some View {
        HStack(spacing: 8) {
            Image(systemName: "slider.horizontal.3")
                .font(.caption).foregroundStyle(.secondary)
            Text("Difficulty")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: $naturalOnly) {
                Text("Natural (7)").tag(true)
                Text("Chromatic (12)").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Note Grid

    private var noteGrid: some View {
        let cols = naturalOnly
            ? [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

        return LazyVGrid(columns: cols, spacing: 10) {
            ForEach(displayedNotes, id: \.self) { chroma in
                let state = btnState(for: chroma)
                Button { submitAnswer(chroma: chroma) } label: {
                    Text(chromaticNames[chroma])
                        .font(.system(size: naturalOnly ? 17 : 14, weight: .bold))
                        .foregroundStyle(labelColor(state))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, naturalOnly ? 16 : 14)
                        .background(bgColor(state), in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(phase != .answering)
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        if phase == .idle {
            Button { newDrill() } label: {
                Label("Play a Note", systemImage: "play.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color(red: 0.7, green: 0.5, blue: 0.1))
                    .foregroundStyle(.white).fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PressableButtonStyle())
        } else if phase == .revealed {
            Button { newDrill() } label: {
                Text("Next Note →")
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color(red: 0.7, green: 0.5, blue: 0.1))
                    .foregroundStyle(.white).fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: - Feedback Card

    @ViewBuilder
    private var feedbackCard: some View {
        if let sel = selectedChroma {
            let targetChroma = targetMidi % 12
            let correct = sel == targetChroma
            let octave = (targetMidi / 12) - 1
            HStack(spacing: 10) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(correct ? .green : .red).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(correct
                         ? "Correct! That was \(chromaticNames[targetChroma])\(octave) +15 XP"
                         : "It was \(chromaticNames[targetChroma])\(octave) — you said \(chromaticNames[sel])")
                        .font(.headline).foregroundStyle(correct ? .green : .red)
                    Text(correct
                         ? "Your pitch memory is building"
                         : "Replay and hold the sound in your mind before answering")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background((correct ? Color.green : Color.red).opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Helpers

    private var targetChroma: Int { targetMidi % 12 }

    private func btnState(for chroma: Int) -> APBtnState {
        guard phase == .revealed, let sel = selectedChroma else { return .idle }
        if chroma == targetChroma { return .correct }
        if chroma == sel { return .wrong }
        return .dimmed
    }

    private func bgColor(_ s: APBtnState) -> Color {
        switch s {
        case .idle:    return Color(.secondarySystemBackground)
        case .correct: return Color.green
        case .wrong:   return Color.red
        case .dimmed:  return Color(.systemFill)
        }
    }

    private func labelColor(_ s: APBtnState) -> Color {
        s == .idle || s == .dimmed ? .primary : .white
    }

    // MARK: - Logic

    private func newDrill() {
        // Filter to notes that match displayed chromas
        let validPool = notePool.filter { displayedNotes.contains($0 % 12) }
        targetMidi = validPool.randomElement() ?? 60
        selectedChroma = nil
        phase = .playing
        sessionStart = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            AudioEngine.shared.playNote(midiNote: UInt8(targetMidi), duration: 2.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                withAnimation { phase = .answering }
            }
        }
    }

    private func replayNote() {
        AudioEngine.shared.playNote(midiNote: UInt8(targetMidi), duration: 2.5)
    }

    private func submitAnswer(chroma: Int) {
        guard phase == .answering else { return }
        selectedChroma = chroma
        withAnimation { phase = .revealed }
        score.total += 1
        let correct = chroma == targetChroma
        if correct {
            score.correct += 1
            HapticsManager.success()
            userProfile.addXP(15)
        } else {
            HapticsManager.error()
        }
        modelContext.insert(DrillResult(
            module: .absolutePitch,
            drillType: "ap_\(chromaticNames[targetChroma].lowercased())",
            wasCorrect: correct,
            responseTime: Date().timeIntervalSince(sessionStart)
        ))
        sessionStart = Date()
    }
}
