import SwiftUI

struct IntervalModuleView: View {
    @State private var selectedInterval: Interval = .majorThird
    @State private var selectedDirection: IntervalDirection = .ascending
    @State private var showDrill = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                directionPicker
                intervalGrid
                startButton
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Interval Recognition")
        .sheet(isPresented: $showDrill) {
            IntervalDrillView(
                drillType: "interval_\(selectedInterval.name.lowercased().replacingOccurrences(of: " ", with: "_"))_\(selectedDirection.rawValue.lowercased())",
                onComplete: { _, _ in }
            )
        }
    }

    private var directionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Direction")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Picker("Direction", selection: $selectedDirection) {
                ForEach(IntervalDirection.allCases, id: \.self) {
                    Text($0.rawValue).tag($0)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
    }

    private var intervalGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Interval")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Interval.allCases.filter { $0 != .unison }, id: \.self) { interval in
                    Button {
                        selectedInterval = interval
                    } label: {
                        VStack(spacing: 4) {
                            Text(interval.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(interval.mnemonic)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedInterval == interval ? Color.purple : Color(.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(selectedInterval == interval ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
    }

    private var startButton: some View {
        Button {
            showDrill = true
        } label: {
            Label("Practice \(selectedInterval.name)", systemImage: "play.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.purple)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Interval Drill View

struct IntervalDrillView: View {
    let drillType: String
    let onComplete: (Bool, TimeInterval) -> Void

    @StateObject private var audio = AudioEngine.shared
    @State private var rootMidi: UInt8 = 60
    @State private var targetInterval: Interval = .majorThird
    @State private var direction: IntervalDirection = .ascending
    @State private var choices: [Interval] = []
    @State private var answered: Interval? = nil
    @State private var startTime = Date()
    @State private var showMnemonic = false

    private var isCorrect: Bool? {
        guard let answered else { return nil }
        return answered == targetInterval
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            playButton
            intervalLabel

            if showMnemonic {
                Text(targetInterval.mnemonic)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            Spacer()

            answerGrid

            if answered != nil {
                nextButton
            }
        }
        .padding()
        .onAppear { newDrill() }
    }

    private var playButton: some View {
        Button {
            playInterval()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.purple)
                Text("Tap to play")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var intervalLabel: some View {
        Text(direction.rawValue)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.purple.opacity(0.1), in: Capsule())
    }

    private var answerGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(choices, id: \.self) { interval in
                Button {
                    guard answered == nil else { return }
                    answered = interval
                    let time = Date().timeIntervalSince(startTime)
                    let correct = interval == targetInterval
                    if !correct { showMnemonic = true }
                    onComplete(correct, time)
                } label: {
                    Text(interval.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(buttonColor(for: interval), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(answered != nil ? .white : .primary)
                }
                .buttonStyle(.plain)
                .disabled(answered != nil)
            }
        }
    }

    private func buttonColor(for interval: Interval) -> Color {
        guard let answered else { return Color(.secondarySystemBackground) }
        if interval == targetInterval { return .green }
        if interval == answered { return .red }
        return Color(.secondarySystemBackground)
    }

    private var nextButton: some View {
        Button {
            newDrill()
        } label: {
            Text(isCorrect == true ? "Next →" : "Try Again →")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.purple)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .fontWeight(.semibold)
        }
    }

    private func newDrill() {
        answered = nil
        showMnemonic = false
        startTime = Date()
        rootMidi = UInt8.random(in: 48...72)
        targetInterval = Interval.allCases.filter { $0 != .unison }.randomElement()!
        direction = IntervalDirection.allCases.randomElement()!
        choices = buildChoices(correct: targetInterval)
        playInterval()
    }

    private func playInterval() {
        AudioEngine.shared.playInterval(
            rootMidi: rootMidi,
            interval: targetInterval,
            direction: direction
        )
    }

    private func buildChoices(correct: Interval) -> [Interval] {
        var pool = Interval.allCases.filter { $0 != .unison && $0 != correct }
        pool.shuffle()
        let distractors = Array(pool.prefix(3))
        return ([correct] + distractors).shuffled()
    }
}
