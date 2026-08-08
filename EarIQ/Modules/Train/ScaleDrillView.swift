import SwiftUI

struct ScaleModuleView: View {
    @State private var showDrill = false
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Scale Recognition")
                    .font(.title2).fontWeight(.bold)
                Text("Hear a scale and identify it. Starts with Major, Natural Minor, and Major Pentatonic.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 16))

            Button { showDrill = true } label: {
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
        .navigationTitle("Scale Recognition")
        .sheet(isPresented: $showDrill) {
            ScaleDrillView(drillType: "scale_practice", onComplete: { _, _ in })
        }
    }
}

struct ScaleDrillView: View {
    let drillType: String
    let onComplete: (Bool, TimeInterval) -> Void
    @EnvironmentObject private var storeManager: StoreManager

    @State private var rootMidi: UInt8 = 60
    @State private var targetScale: ScaleType = .major
    @State private var choices: [ScaleType] = []
    @State private var answered: ScaleType? = nil
    @State private var startTime = Date()

    private var availableScales: [ScaleType] {
        storeManager.isPro ? ScaleType.allCases : ScaleType.allCases.filter(\.freeForAll)
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Button { playScale() } label: {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 56))
                    .foregroundStyle(.purple)
            }
            .buttonStyle(.plain)
            Text("Which scale did you hear?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(choices, id: \.self) { scale in
                    Button {
                        guard answered == nil else { return }
                        answered = scale
                        onComplete(scale == targetScale, Date().timeIntervalSince(startTime))
                    } label: {
                        Text(scale.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(buttonColor(for: scale), in: RoundedRectangle(cornerRadius: 12))
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

    private func buttonColor(for scale: ScaleType) -> Color {
        guard let answered else { return Color(.secondarySystemBackground) }
        if scale == targetScale { return .green }
        if scale == answered { return .red }
        return Color(.secondarySystemBackground)
    }

    private func newDrill() {
        answered = nil
        startTime = Date()
        rootMidi = UInt8.random(in: 48...65)
        targetScale = availableScales.randomElement() ?? .major
        var pool = availableScales.filter { $0 != targetScale }
        pool.shuffle()
        choices = ([targetScale] + pool.prefix(3)).shuffled()
        playScale()
    }

    private func playScale() {
        AudioEngine.shared.playScale(rootMidi: rootMidi, type: targetScale)
    }
}
