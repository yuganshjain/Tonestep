import SwiftUI

struct FunctionalEarModuleView: View {
    @State private var showDrill = false
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Functional Ear Training")
                    .font(.title2).fontWeight(.bold)
                Text("The most important ear training skill. A key is established, then a note plays — identify its scale degree.")
                    .foregroundStyle(.secondary)
                Text("This is what lets you transcribe melodies and improvise.")
                    .font(.caption)
                    .foregroundStyle(.purple)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 16))

            Button { showDrill = true } label: {
                Label("Start Training", systemImage: "ear.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .fontWeight(.semibold)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Functional Ear")
        .sheet(isPresented: $showDrill) {
            FunctionalEarDrillView(drillType: "functional_degree", onComplete: { _, _ in })
        }
    }
}

struct FunctionalEarDrillView: View {
    let drillType: String
    let onComplete: (Bool, TimeInterval) -> Void
    @EnvironmentObject private var userProfile: UserProfileStore
    @EnvironmentObject private var storeManager: StoreManager

    @State private var rootMidi: UInt8 = 60
    @State private var targetDegree: ScaleDegree = .do_
    @State private var choices: [ScaleDegree] = []
    @State private var answered: ScaleDegree? = nil
    @State private var startTime = Date()
    @State private var cadencePlayed = false

    private var activeDegrees: [ScaleDegree] {
        storeManager.isPro ? ScaleDegree.fullSet : ScaleDegree.beginnerSet
    }

    private var usesSolfege: Bool { userProfile.solfegeStyle == .doReMi }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Button { playCadenceThenNote() } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
                Text(cadencePlayed ? "Tap to replay" : "Tap to play")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Key: \(noteName(for: rootMidi))")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            Text("Which scale degree did you hear?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Solfège grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: min(choices.count, 4)), spacing: 12) {
                ForEach(choices, id: \.self) { degree in
                    Button {
                        guard answered == nil else { return }
                        answered = degree
                        onComplete(degree == targetDegree, Date().timeIntervalSince(startTime))
                    } label: {
                        VStack(spacing: 2) {
                            Text(usesSolfege ? degree.solfege : degree.numberLabel)
                                .font(.title3)
                                .fontWeight(.bold)
                            if answered != nil {
                                Text(degree.stabilityDescription.components(separatedBy: "—").first ?? "")
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(buttonColor(for: degree), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(answered != nil ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(answered != nil)
                }
            }

            if let answered {
                VStack(spacing: 8) {
                    if answered == targetDegree {
                        Label("Correct! \(targetDegree.solfege) — \(targetDegree.stabilityDescription)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    } else {
                        Label("That was \(targetDegree.solfege) — \(targetDegree.stabilityDescription)", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.subheadline)
                    }
                    Button { newDrill() } label: {
                        Text("Next →")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.purple)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding()
        .onAppear { newDrill() }
    }

    private func buttonColor(for degree: ScaleDegree) -> Color {
        guard let answered else { return Color(.secondarySystemBackground) }
        if degree == targetDegree { return .green }
        if degree == answered { return .red }
        return Color(.secondarySystemBackground)
    }

    private func newDrill() {
        answered = nil
        cadencePlayed = false
        startTime = Date()
        rootMidi = UInt8.random(in: 53...67)
        targetDegree = activeDegrees.randomElement() ?? .do_
        var pool = activeDegrees.filter { $0 != targetDegree }
        pool.shuffle()
        choices = ([targetDegree] + pool.prefix(3)).shuffled()
        playCadenceThenNote()
    }

    private func playCadenceThenNote() {
        AudioEngine.shared.playCadence(rootMidi: rootMidi, tempo: 0.4)
        let cadenceDuration = 0.4 * 4 + 0.6
        let noteMidi = UInt8(clamping: Int(rootMidi) + targetDegree.semitoneFromRoot)
        DispatchQueue.main.asyncAfter(deadline: .now() + cadenceDuration) {
            AudioEngine.shared.playNote(midiNote: noteMidi, duration: 1.5)
            self.cadencePlayed = true
            self.startTime = Date()
        }
    }

    private func noteName(for midi: UInt8) -> String {
        let names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        return names[Int(midi) % 12]
    }
}
