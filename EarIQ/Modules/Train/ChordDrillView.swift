import SwiftUI

struct ChordModuleView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @State private var showDrill = false

    private var availableChords: [ChordQuality] {
        ChordQuality.allCases.filter { !$0.isProOnly || storeManager.isPro }
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Chord Recognition")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Hear a chord and identify its quality. Start with triads.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 16))

            Button {
                showDrill = true
            } label: {
                Label("Start Practice", systemImage: "play.fill")
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
        .navigationTitle("Chord Recognition")
        .sheet(isPresented: $showDrill) {
            ChordDrillView(drillType: "chord_practice", onComplete: { _, _ in })
        }
    }
}

struct ChordDrillView: View {
    let drillType: String
    let onComplete: (Bool, TimeInterval) -> Void
    @EnvironmentObject private var storeManager: StoreManager

    @State private var rootMidi: UInt8 = 60
    @State private var targetChord: ChordQuality = .major
    @State private var choices: [ChordQuality] = []
    @State private var answered: ChordQuality? = nil
    @State private var startTime = Date()

    private var availableChords: [ChordQuality] {
        ChordQuality.allCases.filter { !$0.isProOnly || storeManager.isPro }
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Button { playChord() } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.purple)
            }
            .buttonStyle(.plain)
            Text("What type of chord is this?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(choices, id: \.self) { chord in
                    Button {
                        guard answered == nil else { return }
                        answered = chord
                        let time = Date().timeIntervalSince(startTime)
                        onComplete(chord == targetChord, time)
                    } label: {
                        Text(chord.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(buttonColor(for: chord), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(answered != nil ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(answered != nil)
                }
            }
            if answered != nil {
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
        .padding()
        .onAppear { newDrill() }
    }

    private func buttonColor(for chord: ChordQuality) -> Color {
        guard let answered else { return Color(.secondarySystemBackground) }
        if chord == targetChord { return .green }
        if chord == answered { return .red }
        return Color(.secondarySystemBackground)
    }

    private func newDrill() {
        answered = nil
        startTime = Date()
        rootMidi = UInt8.random(in: 48...72)
        targetChord = availableChords.randomElement() ?? .major
        var pool = availableChords.filter { $0 != targetChord }
        pool.shuffle()
        choices = ([targetChord] + pool.prefix(3)).shuffled()
        playChord()
    }

    private func playChord() {
        AudioEngine.shared.playChord(rootMidi: rootMidi, quality: targetChord)
    }
}
