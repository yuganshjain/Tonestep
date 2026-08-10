import SwiftUI

struct ChordModuleView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @State private var showDrill = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                chordList
                startButton
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Chord Recognition")
        .fullScreenCover(isPresented: $showDrill) {
            NavigationStack {
                ChordDrillView(drillType: "chord_practice", onComplete: { _, _ in })
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Done") { showDrill = false }
                        }
                    }
            }
        }
    }

    private var headerCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.purple.opacity(0.15)).frame(width: 52, height: 52)
                Image(systemName: "music.note").font(.title2).foregroundStyle(Color.purple)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Hear a chord and identify its quality.")
                    .font(.subheadline)
                Text("Starts with triads. Unlock 7ths and inversions with Pro.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var chordList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chord Types").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            ForEach(ChordQuality.allCases, id: \.self) { chord in
                HStack {
                    Text(chord.rawValue).font(.subheadline)
                    Spacer()
                    if chord.isProOnly && !storeManager.isPro {
                        Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "checkmark").font(.caption).foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 8)
                .opacity(chord.isProOnly && !storeManager.isPro ? 0.5 : 1)
                if chord != ChordQuality.allCases.last { Divider() }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var startButton: some View {
        Button { showDrill = true } label: {
            Label("Start Practice", systemImage: "play.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.purple)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .fontWeight(.semibold)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct ChordDrillView: View {
    let drillType: String
    /// When supplied, this exact drill is rendered instead of a random one.
    var spec: DrillSpec? = nil
    let onComplete: (Bool, TimeInterval) -> Void
    @EnvironmentObject private var storeManager: StoreManager

    @State private var rootMidi: UInt8 = 60
    @State private var targetChord: ChordQuality = .major
    @State private var choices: [ChordQuality] = []
    @State private var answered: ChordQuality? = nil
    @State private var startTime = Date()
    @State private var isPlaying = false

    private var availableChords: [ChordQuality] {
        ChordQuality.allCases.filter { !$0.isProOnly || storeManager.isPro }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Button { playChord() } label: {
                ZStack {
                    Circle().fill(Color.purple.opacity(0.10)).frame(width: 120, height: 120)
                        .scaleEffect(isPlaying ? 1.15 : 1.0)
                        .animation(.easeOut(duration: 0.4), value: isPlaying)
                    Circle()
                        .fill(LinearGradient(colors: [Color.purple, Color(red: 0.5, green: 0.1, blue: 0.9)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 88, height: 88)
                    Image(systemName: "music.note")
                        .font(.system(size: 36)).foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 6) {
                Text("What type of chord?").font(.title3).fontWeight(.semibold)
                Text("Tap to replay anytime").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(choices, id: \.self) { chord in
                    AnswerButton(
                        label: chord.rawValue,
                        state: buttonState(for: chord),
                        action: { select(chord) }
                    )
                }
            }
            if answered != nil { feedbackBar }
        }
        .padding(.horizontal, 20).padding(.bottom, 20)
        .onAppear { newDrill() }
    }

    private var feedbackBar: some View {
        let correct = answered == targetChord
        return HStack {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(correct ? .green : .red)
            Text(correct ? "Correct!" : "That was \(targetChord.rawValue)")
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(correct ? .green : .red)
            Spacer()
            Button { newDrill() } label: {
                Text("Next →").fontWeight(.semibold).foregroundStyle(Color.purple)
            }
        }
        .padding()
        .background((correct ? Color.green : Color.red).opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: answered)
    }

    private func buttonState(for chord: ChordQuality) -> AnswerButtonState {
        guard let answered else { return .idle }
        if chord == targetChord { return .correct }
        if chord == answered { return .wrong }
        return .dimmed
    }

    private func select(_ chord: ChordQuality) {
        guard answered == nil else { return }
        HapticsManager.light()
        answered = chord
        onComplete(chord == targetChord, Date().timeIntervalSince(startTime))
    }

    private func newDrill() {
        answered = nil
        startTime = Date()
        if let spec, case .chord(let quality) = spec.item {
            rootMidi = spec.rootMidi
            targetChord = quality
            choices = spec.choices.compactMap {
                if case .chord(let c) = $0 { return c } else { return nil }
            }
        } else {
            rootMidi = UInt8.random(in: 48...72)
            targetChord = availableChords.randomElement() ?? .major
            var pool = availableChords.filter { $0 != targetChord }; pool.shuffle()
            choices = ([targetChord] + pool.prefix(3)).shuffled()
        }
        playChord()
    }

    private func playChord() {
        isPlaying = true
        AudioEngine.shared.playChord(rootMidi: rootMidi, quality: targetChord)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { isPlaying = false }
    }
}
