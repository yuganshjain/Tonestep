import SwiftUI
import SwiftData

struct SingingPracticeModuleView: View {
    var body: some View {
        NavigationStack {
            SingingDrillView()
                .navigationTitle("Singing Practice")
                .navigationBarTitleDisplayMode(.large)
        }
    }
}

private enum SingPhase { case idle, listening, held, scored }

struct SingingDrillView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var userProfile: UserProfileStore
    @StateObject private var detector = PitchDetector()

    // Target note
    @State private var targetMidi: Int = 60
    @State private var targetName: String = "C4"

    // Mic / pitch state
    @State private var phase: SingPhase = .idle
    @State private var centsOffset: Double = 0
    @State private var heldDuration: Double = 0
    @State private var timer: Timer?
    @State private var wasCorrect = false

    // Session
    @State private var score = (correct: 0, total: 0)
    @State private var sessionStart = Date()

    // Available notes: pentatonic across 2 octaves (C3-C5)
    private let targets: [(midi: Int, name: String)] = [
        (48,"C3"),(50,"D3"),(52,"E3"),(55,"G3"),(57,"A3"),
        (60,"C4"),(62,"D4"),(64,"E4"),(67,"G4"),(69,"A4"),
        (72,"C5")
    ]

    private let holdRequired: Double = 0.9   // seconds in tune
    private let tuneThreshold: Double = 25   // cents tolerance

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                scoreBar
                targetDisplay
                pitchMeter
                controlArea
                if phase == .scored { resultCard }
                if phase == .scored { nextButton }
                Spacer()
            }
            .padding()
            .padding(.bottom, 100)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { newNote() }
        .onDisappear { stopSession() }
    }

    // MARK: - Sub-views

    private var scoreBar: some View {
        HStack {
            Label("\(score.correct)/\(score.total)", systemImage: "checkmark.circle.fill")
                .font(.subheadline).fontWeight(.semibold).foregroundStyle(.green)
            Spacer()
            Label("Singing Practice", systemImage: "mic.fill")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }

    private var targetDisplay: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [Color(red:0.3,green:0.05,blue:0.7), Color(red:0.5,green:0.1,blue:0.6)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 140, height: 140)

                VStack(spacing: 2) {
                    Text(targetName)
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Sing this note")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .scaleEffect(phase == .held ? 1.06 : 1.0)
            .animation(.spring(response: 0.3), value: phase)

            // Reference play button
            Button {
                AudioEngine.shared.playNote(midiNote: UInt8(targetMidi), duration: 1.5)
            } label: {
                Label("Hear Reference", systemImage: "speaker.wave.2.fill")
                    .font(.caption).fontWeight(.medium)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.purple.opacity(0.12))
                    .foregroundStyle(Color.purple)
                    .clipShape(Capsule())
            }
        }
    }

    private var pitchMeter: some View {
        VStack(spacing: 10) {
            // Detected note label
            HStack {
                Text("You:")
                    .font(.caption).foregroundStyle(.secondary)
                Text(detectedLabel)
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(meterColor)
                Spacer()
                if phase == .listening || phase == .held {
                    Text(inTuneLabel)
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(meterColor)
                }
            }

            // Cents bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemFill))
                        .frame(height: 16)

                    // Center line
                    Rectangle()
                        .fill(Color.green.opacity(0.6))
                        .frame(width: 3, height: 22)
                        .offset(x: geo.size.width / 2 - 1.5)

                    // Tolerance zone
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green.opacity(0.15))
                        .frame(width: geo.size.width * (tuneThreshold * 2) / 100, height: 16)
                        .offset(x: geo.size.width / 2 - geo.size.width * tuneThreshold / 100)

                    // Indicator
                    if phase == .listening || phase == .held {
                        Circle()
                            .fill(meterColor)
                            .frame(width: 20, height: 20)
                            .offset(x: clampedIndicatorX(width: geo.size.width) - 10)
                            .animation(.spring(response: 0.15, dampingFraction: 0.8), value: centsOffset)
                    }
                }
            }
            .frame(height: 20)

            HStack {
                Text("♭ Flat").font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Text("In Tune").font(.system(size: 10)).foregroundStyle(.green)
                Spacer()
                Text("Sharp ♯").font(.system(size: 10)).foregroundStyle(.secondary)
            }

            // Hold progress bar
            if phase == .listening || phase == .held {
                VStack(spacing: 4) {
                    Text("Hold: \(Int(heldDuration / holdRequired * 100))%")
                        .font(.caption2).foregroundStyle(.secondary)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemFill)).frame(height: 8)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.green)
                                .frame(width: geo.size.width * min(heldDuration / holdRequired, 1.0), height: 8)
                                .animation(.linear(duration: 0.05), value: heldDuration)
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var controlArea: some View {
        Group {
            switch phase {
            case .idle:
                VStack(spacing: 10) {
                    micFailureNotice
                    Button { startListening() } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mic.fill")
                            Text("Start Singing")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.purple)
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(PressableButtonStyle())
                }

            case .listening, .held:
                Button { stopListening(wasCorrect: false) } label: {
                    HStack(spacing: 10) {
                        Circle().fill(Color.red).frame(width: 12, height: 12)
                        Text("Stop")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

            case .scored:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var resultCard: some View {
        HStack(spacing: 10) {
            Image(systemName: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(wasCorrect ? .green : .red).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(wasCorrect ? "In tune! +15 XP" : "Keep practicing")
                    .font(.headline).foregroundStyle(wasCorrect ? .green : .red)
                Text(wasCorrect ? "You held \(targetName) accurately" : "Try again or move on")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background((wasCorrect ? Color.green : Color.red).opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var nextButton: some View {
        Button { newNote() } label: {
            Text("Next Note")
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(Color.purple).foregroundStyle(.white)
                .fontWeight(.semibold).clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableButtonStyle())
    }

    // MARK: - Helpers

    private var detectedLabel: String {
        guard let midi = detector.detectedMidi else { return "—" }
        let names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        let name = names[(midi % 12 + 12) % 12]
        let octave = (midi / 12) - 1
        return "\(name)\(octave)"
    }

    private var inTuneLabel: String {
        let a = abs(centsOffset)
        if a < tuneThreshold { return "✓ In tune" }
        return centsOffset < 0 ? "Too flat" : "Too sharp"
    }

    private var meterColor: Color {
        let a = abs(centsOffset)
        if a < tuneThreshold { return .green }
        if a < 50 { return .yellow }
        return .red
    }

    private func clampedIndicatorX(width: CGFloat) -> CGFloat {
        let center = width / 2
        let scale = width / 100
        return min(max(center + centsOffset * scale, 0), width)
    }

    // MARK: - Logic

    private func newNote() {
        let t = targets.randomElement()!
        targetMidi = t.midi
        targetName = t.name
        centsOffset = 0
        heldDuration = 0
        wasCorrect = false
        phase = .idle
        detector.detectedMidi = nil
    }

    private func startListening() {
        detector.failureReason = nil
        phase = .listening
        detector.startListening()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            updatePitchFeedback()
        }
        // If the mic never comes up, drop back to idle so the exercise does not
        // sit in a listening state that will never receive audio.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if detector.failureReason != nil {
                timer?.invalidate()
                phase = .idle
            }
        }
    }

    @ViewBuilder
    private var micFailureNotice: some View {
        if let reason = detector.failureReason {
            HStack(spacing: 10) {
                Image(systemName: "mic.slash.fill")
                    .foregroundStyle(.orange)
                Text(reason == .permissionDenied
                     ? "Microphone access is off. Turn it on in Settings to sing along."
                     : "The microphone isn't available right now.")
                    .font(.caption)
                    .foregroundStyle(TrainingModule.pastelSubtext)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func updatePitchFeedback() {
        guard let detected = detector.detectedMidi else {
            centsOffset = 0
            heldDuration = 0
            return
        }

        // Compute cents offset (detected vs target)
        let semitonesDiff = Double(detected - targetMidi)
        // Approximate cents from raw MIDI difference
        centsOffset = semitonesDiff * 100

        // Clamp to ±100
        centsOffset = max(-100, min(100, centsOffset))

        if abs(centsOffset) < tuneThreshold {
            heldDuration += 0.05
            if heldDuration >= holdRequired {
                stopListening(wasCorrect: true)
            }
        } else {
            heldDuration = max(0, heldDuration - 0.03)
        }
    }

    private func stopListening(wasCorrect: Bool) {
        timer?.invalidate()
        timer = nil
        detector.stopListening()
        self.wasCorrect = wasCorrect
        phase = .scored
        score.total += 1
        if wasCorrect {
            score.correct += 1
            HapticsManager.success()
        } else {
            HapticsManager.error()
        }

        let result = DrillResult(module: .singingPractice,
                                 drillType: "sing_\(targetName)",
                                 wasCorrect: wasCorrect,
                                 responseTime: Date().timeIntervalSince(sessionStart))
        modelContext.insert(result)
        DrillRecorder.grade(result, context: modelContext)
        if wasCorrect { userProfile.addXP(15) }
    }

    private func stopSession() {
        timer?.invalidate()
        detector.stopListening()
    }
}
