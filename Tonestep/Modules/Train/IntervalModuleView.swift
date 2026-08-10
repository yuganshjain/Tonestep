import SwiftUI

struct IntervalModuleView: View {
    @State private var selectedDirection: IntervalDirection = .ascending
    @State private var showDrill = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                directionPicker
                intervalList
                startButton
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Interval Recognition")
        .fullScreenCover(isPresented: $showDrill) {
            NavigationStack {
                IntervalDrillView(drillType: "interval_free_drill", onComplete: { _, _ in })
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
                Image(systemName: "arrow.up.right").font(.title2).foregroundStyle(Color.purple)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Hear the gap between two notes and name the interval.")
                    .font(.subheadline)
                Text("Tip: Each interval has a famous song mnemonic.")
                    .font(.caption).foregroundStyle(Color.purple)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var directionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Direction").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            Picker("Direction", selection: $selectedDirection) {
                ForEach(IntervalDirection.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var intervalList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All 13 Intervals").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            ForEach(Interval.allCases.filter { $0 != .unison }, id: \.self) { interval in
                HStack {
                    Text(interval.name).font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Text(interval.mnemonic).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                if interval != .octave { Divider() }
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

// MARK: - Interval Drill (premium UI)

struct IntervalDrillView: View {
    let drillType: String
    /// When supplied, this exact drill is rendered instead of a random one.
    /// nil keeps the existing free-practice behaviour, so no call site changes.
    var spec: DrillSpec? = nil
    let onComplete: (Bool, TimeInterval) -> Void

    @State private var rootMidi: UInt8 = 60
    @State private var targetInterval: Interval = .majorThird
    @State private var direction: IntervalDirection = .ascending
    @State private var choices: [Interval] = []
    @State private var answered: Interval? = nil
    @State private var startTime = Date()
    @State private var isPlaying = false
    @State private var pulseAmount: CGFloat = 1.0
    @State private var shakeOffset: CGFloat = 0
    @State private var showMnemonic = false

    private var isCorrect: Bool? {
        guard let answered else { return nil }
        return answered == targetInterval
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            speakerSection
            Spacer()
            questionLabel
            Spacer()
            answerGrid
            if let correct = isCorrect {
                feedbackSection(correct: correct)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .onAppear { newDrill() }
    }

    private var speakerSection: some View {
        Button { playInterval() } label: {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isPlaying ? 1.15 : 1.0)
                    .animation(.easeOut(duration: 0.4), value: isPlaying)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color(red: 0.5, green: 0.1, blue: 0.9)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                Image(systemName: isPlaying ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                    .symbolEffect(.variableColor.iterative.dimInactiveLayers, isActive: isPlaying)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPlaying)
    }

    private var questionLabel: some View {
        VStack(spacing: 8) {
            Text("What interval is this?")
                .font(.title3).fontWeight(.semibold)
            HStack(spacing: 8) {
                Label(direction.rawValue, systemImage: directionIcon)
                    .font(.caption)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.purple.opacity(0.12), in: Capsule())
                    .foregroundStyle(Color.purple)
                if showMnemonic {
                    Text(targetInterval.mnemonic)
                        .font(.caption)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                        .foregroundStyle(.orange)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showMnemonic)
        }
    }

    private var directionIcon: String {
        switch direction {
        case .ascending: return "arrow.up.right"
        case .descending: return "arrow.down.right"
        case .harmonic: return "arrow.up.and.down"
        }
    }

    private var answerGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(choices, id: \.self) { interval in
                AnswerButton(
                    label: interval.name,
                    state: buttonState(for: interval),
                    action: { select(interval) }
                )
            }
        }
    }

    private func feedbackSection(correct: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(correct ? .green : .red)
            Text(correct ? "Correct!" : "That was \(targetInterval.name)")
                .font(.subheadline).fontWeight(.medium)
                .foregroundStyle(correct ? .green : .red)
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { newDrill() }
            } label: {
                Text("Next →").fontWeight(.semibold).foregroundStyle(Color.purple)
            }
        }
        .padding()
        .background(
            (correct ? Color.green : Color.red).opacity(0.08),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: answered)
    }

    private func buttonState(for interval: Interval) -> AnswerButtonState {
        guard let answered else { return .idle }
        if interval == targetInterval { return .correct }
        if interval == answered { return .wrong }
        return .dimmed
    }

    private func select(_ interval: Interval) {
        guard answered == nil else { return }
        HapticsManager.light()
        answered = interval
        let time = Date().timeIntervalSince(startTime)
        let correct = interval == targetInterval
        if !correct { showMnemonic = true }
        onComplete(correct, time)
    }

    private func newDrill() {
        answered = nil
        showMnemonic = false
        startTime = Date()

        if let spec, case .interval(let interval) = spec.item {
            rootMidi = spec.rootMidi
            targetInterval = interval
            direction = Self.direction(for: spec.voicing)
            choices = spec.choices.compactMap {
                if case .interval(let i) = $0 { return i } else { return nil }
            }
        } else {
            rootMidi = UInt8.random(in: 48...72)
            targetInterval = Interval.allCases.filter { $0 != .unison }.randomElement()!
            direction = IntervalDirection.allCases.randomElement()!
            choices = buildChoices(correct: targetInterval)
        }
        playInterval()
    }

    private static func direction(for voicing: VoicingMode) -> IntervalDirection {
        switch voicing {
        case .ascending:  return .ascending
        case .descending: return .descending
        case .harmonic:   return .harmonic
        }
    }

    private func playInterval() {
        isPlaying = true
        AudioEngine.shared.playInterval(rootMidi: rootMidi, interval: targetInterval, direction: direction)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { isPlaying = false }
    }

    private func buildChoices(correct: Interval) -> [Interval] {
        var pool = Interval.allCases.filter { $0 != .unison && $0 != correct }
        pool.shuffle()
        return ([correct] + pool.prefix(3)).shuffled()
    }
}

// MARK: - Shared Answer Button

enum AnswerButtonState { case idle, correct, wrong, dimmed }

struct AnswerButton: View {
    let label: String
    let state: AnswerButtonState
    let action: () -> Void
    @State private var shakeOffset: CGFloat = 0
    @State private var scaleEffect: CGFloat = 1.0

    var body: some View {
        Button {
            if state == .idle { action() }
        } label: {
            Text(label)
                .font(.subheadline).fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(backgroundColor, in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(foregroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(borderColor, lineWidth: state == .idle ? 0 : 2)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(scaleEffect)
        .offset(x: shakeOffset)
        .disabled(state != .idle)
        .onChange(of: state) { _, newState in
            if newState == .correct {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { scaleEffect = 1.06 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation { scaleEffect = 1.0 }
                }
            } else if newState == .wrong {
                shake()
            }
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .idle: return Color(.secondarySystemBackground)
        case .correct: return Color.green.opacity(0.2)
        case .wrong: return Color.red.opacity(0.2)
        case .dimmed: return Color(.secondarySystemBackground).opacity(0.5)
        }
    }

    private var foregroundColor: Color {
        switch state {
        case .idle: return .primary
        case .correct: return .green
        case .wrong: return .red
        case .dimmed: return .secondary
        }
    }

    private var borderColor: Color {
        switch state {
        case .correct: return .green
        case .wrong: return .red
        default: return .clear
        }
    }

    private func shake() {
        let offsets: [CGFloat] = [0, -8, 8, -6, 6, -4, 4, 0]
        for (i, offset) in offsets.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.04) {
                withAnimation(.linear(duration: 0.04)) { shakeOffset = offset }
            }
        }
    }
}
