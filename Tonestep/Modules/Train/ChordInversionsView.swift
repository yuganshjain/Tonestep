import SwiftUI
import SwiftData

// MARK: - Chord Inversion type

enum ChordInversion: String, CaseIterable {
    case root = "Root Position"
    case first = "1st Inversion"
    case second = "2nd Inversion"

    var shortName: String {
        switch self {
        case .root: return "Root"
        case .first: return "1st Inv"
        case .second: return "2nd Inv"
        }
    }

    var description: String {
        switch self {
        case .root:   return "Bass note is the root (most stable)"
        case .first:  return "Bass note is the 3rd"
        case .second: return "Bass note is the 5th"
        }
    }

    var symbol: String {
        switch self { case .root: return "⁵₃"; case .first: return "⁶₃"; case .second: return "⁶₄" }
    }

    // Returns MIDI offsets for major chord in this inversion
    func midiOffsets(for quality: ChordQuality) -> [Int] {
        let base = quality.semitones
        switch self {
        case .root:   return base
        case .first:  return Array(base.dropFirst()) + [base[0] + 12]
        case .second:
            if base.count >= 3 {
                return [base[2]] + [base[0] + 12] + [base[1] + 12]
            }
            return base
        }
    }
}

// MARK: - Module wrapper

struct ChordInversionsModuleView: View {
    var body: some View {
        NavigationStack {
            ChordInversionsDrillView()
                .navigationTitle("Chord Inversions")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Drill View

struct ChordInversionsDrillView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userProfile: UserProfileStore

    @State private var targetInversion: ChordInversion = .root
    @State private var targetQuality: ChordQuality = .major
    @State private var rootMidi: UInt8 = 60
    @State private var selected: ChordInversion?
    @State private var isPlaying = false
    @State private var playCount = 0
    @State private var score = (correct: 0, total: 0)
    @State private var drillStart = Date()
    @State private var showInfo = false

    // Only major and minor for beginner inversion practice
    private let qualities: [ChordQuality] = [.major, .minor]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                scoreBar
                infoCard
                playCard
                if selected != nil { resultBanner }
                answerButtons
                if selected != nil { nextButton }
            }
            .padding()
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { nextDrill() }
        .sheet(isPresented: $showInfo) { inversionInfoSheet }
    }

    // MARK: Sub-views

    private var scoreBar: some View {
        HStack {
            Label("\(score.correct)/\(score.total)", systemImage: "checkmark.circle.fill")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.green)
            Spacer()
            Button { showInfo = true } label: {
                Label("What's this?", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.purple)
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var infoCard: some View {
        HStack(spacing: 12) {
            ForEach(ChordInversion.allCases, id: \.self) { inv in
                VStack(spacing: 3) {
                    Text(inv.symbol).font(.system(size: 18, weight: .bold)).foregroundStyle(.purple)
                    Text(inv.shortName).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(targetInversion == inv && selected != nil
                    ? Color.purple.opacity(0.15) : Color(.systemFill),
                    in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var playCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(red:0.5,green:0.1,blue:0.85), Color(red:0.3,green:0.05,blue:0.6)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 110, height: 110)
                Image(systemName: isPlaying ? "waveform" : "music.note.list")
                    .font(.system(size: 42)).foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative, isActive: isPlaying)
            }

            Text(selected == nil ? "Identify the chord inversion" : "\(targetQuality.rawValue) — \(targetInversion.rawValue)")
                .font(.headline)

            Button { playChord() } label: {
                Label(playCount == 0 ? "Play Chord" : "Replay", systemImage: "play.fill")
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(isPlaying ? Color.purple.opacity(0.5) : Color.purple)
                    .foregroundStyle(.white).fontWeight(.semibold)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isPlaying || selected != nil)
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var resultBanner: some View {
        let correct = selected == targetInversion
        HStack(spacing: 10) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(correct ? .green : .red).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(correct ? "Correct! +20 XP" : "It was \(targetInversion.rawValue)")
                    .fontWeight(.semibold).foregroundStyle(correct ? .green : .red)
                Text(targetInversion.description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background((correct ? Color.green : Color.red).opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .transition(.scale.combined(with: .opacity))
    }

    private var answerButtons: some View {
        VStack(spacing: 10) {
            ForEach(ChordInversion.allCases, id: \.self) { inv in
                Button { selectAnswer(inv) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(inv.rawValue).font(.headline)
                            Text(inv.description).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selected != nil {
                            if inv == targetInversion {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            } else if inv == selected {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                            }
                        }
                    }
                    .padding(14)
                    .background(btnBg(inv), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(btnFg(inv))
                }
                .disabled(selected != nil || playCount == 0)
                .buttonStyle(PressableButtonStyle())
            }
        }
    }

    private var nextButton: some View {
        Button { nextDrill() } label: {
            Text("Next Chord").frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.purple).foregroundStyle(.white)
                .fontWeight(.semibold).clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var inversionInfoSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Chord inversions change which note is in the bass — the lowest voice. The same three notes can be arranged three ways.")
                        .foregroundStyle(.secondary)
                    ForEach(ChordInversion.allCases, id: \.self) { inv in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(inv.symbol).font(.title2).fontWeight(.bold).foregroundStyle(.purple)
                                Text(inv.rawValue).font(.headline)
                            }
                            Text(inv.description)
                            Text(inv == .root ? "Sounds: stable, full, resolved"
                                 : inv == .first ? "Sounds: slightly open, mid-air"
                                 : "Sounds: ambiguous, wants to move")
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
            }
            .navigationTitle("Chord Inversions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { showInfo = false }
            }}
        }
    }

    // MARK: Helpers

    private func btnBg(_ inv: ChordInversion) -> Color {
        guard let sel = selected else { return Color(.systemBackground) }
        if inv == targetInversion { return Color.green.opacity(0.15) }
        if inv == sel { return Color.red.opacity(0.15) }
        return Color(.systemBackground).opacity(0.5)
    }

    private func btnFg(_ inv: ChordInversion) -> Color {
        guard let sel = selected else { return .primary }
        if inv == targetInversion { return .green }
        if inv == sel { return .red }
        return .secondary
    }

    // MARK: Logic

    private func nextDrill() {
        targetInversion = ChordInversion.allCases.randomElement()!
        targetQuality = qualities.randomElement()!
        rootMidi = UInt8.random(in: 48...64)
        selected = nil; isPlaying = false; playCount = 0; drillStart = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { playChord() }
    }

    private func playChord() {
        guard !isPlaying else { return }
        isPlaying = true; playCount += 1
        let offsets = targetInversion.midiOffsets(for: targetQuality)
        for offset in offsets {
            let note = UInt8(clamping: Int(rootMidi) + offset)
            AudioEngine.shared.playNote(midiNote: note, velocity: 78, duration: 2.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { isPlaying = false }
    }

    private func selectAnswer(_ inv: ChordInversion) {
        guard selected == nil, playCount > 0 else { return }
        let correct = inv == targetInversion
        withAnimation(.spring(response: 0.3)) { selected = inv }
        score.total += 1
        if correct { score.correct += 1; HapticsManager.success() } else { HapticsManager.error() }
        let result = DrillResult(module: .chordInversions, drillType: "inversion_\(targetInversion.rawValue)",
                                  wasCorrect: correct, responseTime: Date().timeIntervalSince(drillStart))
        modelContext.insert(result)
        DrillRecorder.grade(result, context: modelContext)
        if correct { userProfile.addXP(20) }
    }
}
