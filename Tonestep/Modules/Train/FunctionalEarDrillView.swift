import SwiftUI
import SwiftData

struct FunctionalEarModuleView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userProfile: UserProfileStore
    @State private var showDrill = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                methodCard
                startButton
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Functional Ear")
        .fullScreenCover(isPresented: $showDrill) {
            NavigationStack {
                FunctionalEarDrillView(drillType: "functional_degree") { correct, responseTime in
                        DrillRecorder.record(module: .functionalEar,
                                             drillType: "functional_degree",
                                             correct: correct,
                                             responseTime: responseTime,
                                             context: modelContext,
                                             userProfile: userProfile)
                    }
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
                Image(systemName: "ear.fill").font(.title2).foregroundStyle(Color.purple)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("The most powerful ear training method.")
                    .font(.subheadline)
                Text("A key is established, then you identify the scale degree. This is what separates musicians who can transcribe from those who can't.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var methodCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How It Works").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            ForEach([
                ("1. A cadence plays to set the key.", "music.note"),
                ("2. A single note plays.", "speaker.wave.1.fill"),
                ("3. You identify its scale degree.", "checkmark.circle"),
            ], id: \.0) { step, icon in
                HStack(spacing: 12) {
                    Image(systemName: icon).foregroundStyle(Color.purple).frame(width: 20)
                    Text(step).font(.subheadline)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var startButton: some View {
        Button { showDrill = true } label: {
            Label("Start Training", systemImage: "ear.fill")
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

// MARK: - Functional Ear Drill (premium UI)

struct FunctionalEarDrillView: View {
    let drillType: String
    /// When supplied, this exact drill is rendered instead of a random one.
    var spec: DrillSpec? = nil
    let onComplete: (Bool, TimeInterval) -> Void
    @EnvironmentObject private var userProfile: UserProfileStore
    @EnvironmentObject private var storeManager: StoreManager

    @State private var rootMidi: UInt8 = 60
    @State private var targetDegree: ScaleDegree = .do_
    @State private var choices: [ScaleDegree] = []
    @State private var answered: ScaleDegree? = nil
    @State private var startTime = Date()
    @State private var cadencePlayed = false
    @State private var isPlayingCadence = false
    @State private var isPlayingNote = false

    private var activeDegrees: [ScaleDegree] {
        storeManager.isPro ? ScaleDegree.fullSet : ScaleDegree.beginnerSet
    }
    private var usesSolfege: Bool { userProfile.solfegeStyle == .doReMi }
    private var keyName: String {
        ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"][Int(rootMidi) % 12]
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            playbackSection
            Spacer()
            questionLabel
            Spacer()
            degreeGrid
            if let answered {
                feedbackSection(answered: answered)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .onAppear { newDrill() }
    }

    private var playbackSection: some View {
        VStack(spacing: 20) {
            Button { playCadenceThenNote() } label: {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.10))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isPlayingCadence ? 1.18 : 1.0)
                        .animation(.easeOut(duration: 0.5), value: isPlayingCadence)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isPlayingNote
                                    ? [Color(red: 0.1, green: 0.7, blue: 0.5), Color(red: 0.0, green: 0.5, blue: 0.4)]
                                    : [Color.purple, Color(red: 0.5, green: 0.1, blue: 0.9)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                        .animation(.easeInOut(duration: 0.4), value: isPlayingNote)

                    Image(systemName: isPlayingNote ? "music.note" : "speaker.wave.2.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 4) {
                Text(cadencePlayed ? "Tap to replay" : "Tap to start")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text("Key: \(keyName) major")
                        .font(.caption2).foregroundStyle(.tertiary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(.systemFill), in: Capsule())
                }
            }
        }
    }

    private var questionLabel: some View {
        VStack(spacing: 6) {
            Text("Which scale degree?")
                .font(.title3).fontWeight(.semibold)
            Text(usesSolfege ? "Do · Re · Mi · Fa · Sol · La · Ti" : "1 · 2 · 3 · 4 · 5 · 6 · 7")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var degreeGrid: some View {
        let cols = choices.count <= 4 ? 4 : 4
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible()), count: cols),
            spacing: 12
        ) {
            ForEach(choices, id: \.self) { degree in
                Button {
                    guard answered == nil else { return }
                    HapticsManager.light()
                    answered = degree
                    onComplete(degree == targetDegree, Date().timeIntervalSince(startTime))
                } label: {
                    VStack(spacing: 4) {
                        Text(usesSolfege ? degree.solfege : degree.numberLabel)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        if answered != nil {
                            Text(degree.solfege)
                                .font(.caption2).opacity(0.8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(buttonBg(for: degree), in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(buttonFg(for: degree))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(buttonBorder(for: degree), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .disabled(answered != nil)
            }
        }
    }

    private func feedbackSection(answered: ScaleDegree) -> some View {
        let correct = answered == targetDegree
        return HStack(spacing: 8) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(correct ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text(correct ? "Correct! \(targetDegree.solfege)" : "That was \(targetDegree.solfege)")
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(correct ? .green : .red)
                Text(targetDegree.stabilityDescription)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button { withAnimation { newDrill() } } label: {
                Text("Next →").fontWeight(.semibold).foregroundStyle(Color.purple)
            }
        }
        .padding()
        .background((correct ? Color.green : Color.red).opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: answered)
    }

    private func buttonBg(for degree: ScaleDegree) -> Color {
        guard let answered else { return Color(.secondarySystemBackground) }
        if degree == targetDegree { return Color.green.opacity(0.2) }
        if degree == answered { return Color.red.opacity(0.2) }
        return Color(.secondarySystemBackground).opacity(0.6)
    }
    private func buttonFg(for degree: ScaleDegree) -> Color {
        guard let answered else { return .primary }
        if degree == targetDegree { return .green }
        if degree == answered { return .red }
        return .secondary
    }
    private func buttonBorder(for degree: ScaleDegree) -> Color {
        guard let answered else { return .clear }
        if degree == targetDegree { return .green }
        if degree == answered { return .red }
        return .clear
    }

    private func newDrill() {
        answered = nil
        cadencePlayed = false
        isPlayingNote = false
        isPlayingCadence = false
        startTime = Date()
        if let spec, case .degree(let degree) = spec.item {
            rootMidi = max(53, min(spec.rootMidi, 67))
            targetDegree = degree
            choices = spec.choices.compactMap {
                if case .degree(let d) = $0 { return d } else { return nil }
            }
        } else {
            rootMidi = UInt8.random(in: 53...67)
            targetDegree = activeDegrees.randomElement() ?? .do_
            var pool = activeDegrees.filter { $0 != targetDegree }
            pool.shuffle()
            choices = ([targetDegree] + pool.prefix(3)).shuffled()
        }
        playCadenceThenNote()
    }

    private func playCadenceThenNote() {
        isPlayingCadence = true
        AudioEngine.shared.playCadence(rootMidi: rootMidi, tempo: 0.4)
        let cadenceDuration = 0.4 * 4 + 0.6
        DispatchQueue.main.asyncAfter(deadline: .now() + cadenceDuration) {
            isPlayingCadence = false
            isPlayingNote = true
            let noteMidi = UInt8(clamping: Int(rootMidi) + targetDegree.semitoneFromRoot)
            AudioEngine.shared.playNote(midiNote: noteMidi, duration: 1.5)
            cadencePlayed = true
            startTime = Date()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { isPlayingNote = false }
        }
    }
}
