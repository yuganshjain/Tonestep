import SwiftUI
import SwiftData

struct ScaleModuleView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userProfile: UserProfileStore
    @EnvironmentObject private var storeManager: StoreManager
    @State private var showDrill = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                scaleList
                startButton
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Scale Recognition")
        .fullScreenCover(isPresented: $showDrill) {
            NavigationStack {
                ScaleDrillView(drillType: "scale_practice") { correct, responseTime in
                        DrillRecorder.record(module: .scaleRecognition,
                                             drillType: "scale_practice",
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
                Image(systemName: "waveform.path.ecg").font(.title2).foregroundStyle(Color.purple)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Hear a scale and identify it.")
                    .font(.subheadline)
                Text("Free: Major, Natural Minor, Major Pentatonic. Pro unlocks all 12.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var scaleList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scale Types").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            ForEach(ScaleType.allCases, id: \.self) { scale in
                HStack {
                    Text(scale.rawValue).font(.subheadline)
                    Spacer()
                    if scale.freeForAll || storeManager.isPro {
                        Image(systemName: "checkmark").font(.caption).foregroundStyle(.green)
                    } else {
                        Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .opacity(scale.freeForAll || storeManager.isPro ? 1 : 0.5)
                if scale != ScaleType.allCases.last { Divider() }
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

struct ScaleDrillView: View {
    let drillType: String
    /// When supplied, this exact drill is rendered instead of a random one.
    var spec: DrillSpec? = nil
    let onComplete: (Bool, TimeInterval) -> Void
    @EnvironmentObject private var storeManager: StoreManager

    @State private var rootMidi: UInt8 = 60
    @State private var targetScale: ScaleType = .major
    @State private var choices: [ScaleType] = []
    @State private var answered: ScaleType? = nil
    @State private var startTime = Date()
    @State private var isPlaying = false

    private var availableScales: [ScaleType] {
        storeManager.isPro ? ScaleType.allCases : ScaleType.allCases.filter(\.freeForAll)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Button { playScale() } label: {
                ZStack {
                    Circle().fill(Color.purple.opacity(0.10)).frame(width: 120, height: 120)
                        .scaleEffect(isPlaying ? 1.15 : 1.0)
                        .animation(.easeOut(duration: 0.5), value: isPlaying)
                    Circle()
                        .fill(LinearGradient(colors: [Color.purple, Color(red: 0.5, green: 0.1, blue: 0.9)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 88, height: 88)
                    Image(systemName: "waveform")
                        .font(.system(size: 32)).foregroundStyle(.white)
                        .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                }
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 6) {
                Text("Which scale did you hear?").font(.title3).fontWeight(.semibold)
                Text("Listen to the character — bright, dark, exotic?")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(choices, id: \.self) { scale in
                    AnswerButton(
                        label: scale.rawValue,
                        state: buttonState(for: scale),
                        action: { select(scale) }
                    )
                }
            }
            if answered != nil { feedbackBar }
        }
        .padding(.horizontal, 20).padding(.bottom, 20)
        .onAppear { newDrill() }
    }

    private var feedbackBar: some View {
        let correct = answered == targetScale
        return HStack {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(correct ? .green : .red)
            Text(correct ? "Correct!" : "That was \(targetScale.rawValue)")
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

    private func buttonState(for scale: ScaleType) -> AnswerButtonState {
        guard let answered else { return .idle }
        if scale == targetScale { return .correct }
        if scale == answered { return .wrong }
        return .dimmed
    }

    private func select(_ scale: ScaleType) {
        guard answered == nil else { return }
        HapticsManager.light()
        answered = scale
        onComplete(scale == targetScale, Date().timeIntervalSince(startTime))
    }

    private func newDrill() {
        answered = nil
        startTime = Date()
        if let spec, case .scale(let scale) = spec.item {
            rootMidi = min(spec.rootMidi, 65)
            targetScale = scale
            choices = spec.choices.compactMap {
                if case .scale(let s) = $0 { return s } else { return nil }
            }
        } else {
            rootMidi = UInt8.random(in: 48...65)
            targetScale = availableScales.randomElement() ?? .major
            var pool = availableScales.filter { $0 != targetScale }; pool.shuffle()
            choices = ([targetScale] + pool.prefix(3)).shuffled()
        }
        playScale()
    }

    private func playScale() {
        isPlaying = true
        AudioEngine.shared.playScale(rootMidi: rootMidi, type: targetScale)
        let duration = Double(targetScale.semitones.count) * 0.25 + 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { isPlaying = false }
    }
}
