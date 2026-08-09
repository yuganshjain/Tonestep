import SwiftUI

struct RelativePitchModuleView: View {
    var body: some View {
        NavigationStack {
            RelativePitchDrillView()
                .navigationTitle("Relative Pitch")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

private struct DegreeOption: Identifiable {
    let id: Int
    let semitone: Int
    let label: String
    let solfege: String
}

private let allDegrees: [DegreeOption] = [
    DegreeOption(id: 1,  semitone: 0,  label: "1 · Root",      solfege: "Do"),
    DegreeOption(id: 2,  semitone: 2,  label: "2 · Major 2nd", solfege: "Re"),
    DegreeOption(id: 3,  semitone: 4,  label: "3 · Major 3rd", solfege: "Mi"),
    DegreeOption(id: 4,  semitone: 5,  label: "4 · Perfect 4th", solfege: "Fa"),
    DegreeOption(id: 5,  semitone: 7,  label: "5 · Perfect 5th", solfege: "Sol"),
    DegreeOption(id: 6,  semitone: 9,  label: "6 · Major 6th",  solfege: "La"),
    DegreeOption(id: 7,  semitone: 11, label: "7 · Major 7th",  solfege: "Ti"),
    DegreeOption(id: 8,  semitone: 12, label: "8 · Octave",     solfege: "Do↑"),
]

private enum RPPhase { case idle, playing, answering, revealed }
private enum BtnState { case idle, correct, wrong, dimmed }

struct RelativePitchDrillView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userProfile: UserProfileStore

    @State private var target: DegreeOption = allDegrees[4]
    @State private var phase: RPPhase = .idle
    @State private var selected: Int? = nil
    @State private var score = (correct: 0, total: 0)
    @State private var sessionStart = Date()

    private let rootMidi = 60  // C4 — fixed tonic builds consistent muscle memory

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                contextDisplay
                answerGrid
                actionButton
                if phase == .revealed { feedbackCard }
                Spacer()
            }
            .padding()
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { startDrill() }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack {
            Label("\(score.correct)/\(score.total)", systemImage: "checkmark.circle.fill")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.green)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("Root: C4").font(.caption).foregroundStyle(.secondary)
                Text("Cadence-primed training").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Context Circle

    private var contextDisplay: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.5, green: 0.7, blue: 0.2), Color(red: 0.3, green: 0.55, blue: 0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)

                VStack(spacing: 4) {
                    switch phase {
                    case .idle:
                        Image(systemName: "tuningfork")
                            .font(.system(size: 36)).foregroundStyle(.white)
                    case .playing:
                        ProgressView().tint(.white).scaleEffect(1.3)
                        Text("Listen...").font(.caption).foregroundStyle(.white.opacity(0.8))
                    case .answering, .revealed:
                        Text("Which degree?")
                            .font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                        Text("above C4").font(.caption2).foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .scaleEffect(phase == .playing ? 1.05 : 1.0)
            .animation(.spring(response: 0.4), value: phase == .playing)

            if phase == .answering || phase == .revealed {
                Button { replayCadence() } label: {
                    Label("Replay Cadence", systemImage: "speaker.wave.2.fill")
                        .font(.caption).fontWeight(.medium)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color(red: 0.5, green: 0.7, blue: 0.2).opacity(0.12))
                        .foregroundStyle(Color(red: 0.3, green: 0.55, blue: 0.1))
                        .clipShape(Capsule())
                }
                .disabled(phase == .playing)
            }
        }
    }

    // MARK: - Answer Grid

    private var answerGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(allDegrees) { deg in
                let state = btnState(for: deg.id)
                Button { submitAnswer(deg) } label: {
                    VStack(spacing: 3) {
                        Text(deg.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(labelColor(state))
                        Text(deg.solfege)
                            .font(.system(size: 11))
                            .foregroundStyle(labelColor(state).opacity(0.75))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(bgColor(state), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                Color(red: 0.5, green: 0.7, blue: 0.2).opacity(state == .idle ? 0.25 : 0),
                                lineWidth: 1)
                    )
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
            Button { startDrill() } label: {
                Label("Start Drill", systemImage: "play.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color(red: 0.5, green: 0.7, blue: 0.2))
                    .foregroundStyle(.white).fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PressableButtonStyle())
        } else if phase == .revealed {
            Button { startDrill() } label: {
                Text("Next Degree →")
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color(red: 0.5, green: 0.7, blue: 0.2))
                    .foregroundStyle(.white).fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    // MARK: - Feedback Card

    @ViewBuilder
    private var feedbackCard: some View {
        if let sel = selected {
            let correct = sel == target.id
            HStack(spacing: 10) {
                Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(correct ? .green : .red).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(correct ? "Correct! +20 XP" : "Answer: \(target.label) (\(target.solfege))")
                        .font(.headline).foregroundStyle(correct ? .green : .red)
                    Text(correct ? "Your ears are learning to feel \(target.solfege) in the key"
                               : "The cadence establishes C — hear how \(target.solfege) sits above it")
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

    private func btnState(for id: Int) -> BtnState {
        guard phase == .revealed, let sel = selected else { return .idle }
        if id == target.id { return .correct }
        if id == sel { return .wrong }
        return .dimmed
    }

    private func bgColor(_ s: BtnState) -> Color {
        switch s {
        case .idle:    return Color(.secondarySystemBackground)
        case .correct: return Color.green
        case .wrong:   return Color.red
        case .dimmed:  return Color(.systemFill)
        }
    }

    private func labelColor(_ s: BtnState) -> Color {
        s == .idle || s == .dimmed ? .primary : .white
    }

    // MARK: - Audio Logic

    private func startDrill() {
        var pool = allDegrees
        if score.total > 0 { pool = pool.filter { $0.id != target.id } }
        target = pool.randomElement() ?? allDegrees[4]
        selected = nil
        phase = .playing
        sessionStart = Date()
        playCadenceThenTarget()
    }

    private func playCadenceThenTarget() {
        // C major chord establishes tonal context
        for semitone in [0, 4, 7] {
            AudioEngine.shared.playNote(midiNote: UInt8(rootMidi + semitone), duration: 1.2)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            AudioEngine.shared.playNote(midiNote: UInt8(rootMidi + target.semitone), duration: 2.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation { phase = .answering }
            }
        }
    }

    private func replayCadence() {
        phase = .playing
        playCadenceThenTarget()
    }

    private func submitAnswer(_ deg: DegreeOption) {
        guard phase == .answering else { return }
        selected = deg.id
        withAnimation { phase = .revealed }
        score.total += 1
        let correct = deg.id == target.id
        if correct {
            score.correct += 1
            HapticsManager.success()
            userProfile.addXP(20)
        } else {
            HapticsManager.error()
        }
        modelContext.insert(DrillResult(
            module: .relativePitch,
            drillType: "rp_degree_\(target.id)",
            wasCorrect: correct,
            responseTime: Date().timeIntervalSince(sessionStart)
        ))
        sessionStart = Date()
    }
}
