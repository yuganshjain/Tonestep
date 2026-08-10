import SwiftUI

struct TrainView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @State private var showSpeedRound = false
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    trainHeader
                    playAlongBanner
                    speedRoundBanner
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(TrainingModule.allCases, id: \.self) { module in
                            if module.isComingSoon {
                                ModuleCard(module: module, isLocked: false, isComingSoon: true)
                            } else {
                                NavigationLink { moduleDestination(for: module) } label: {
                                    ModuleCard(module: module, isLocked: module.isProOnly && !storeManager.isPro)
                                }
                                .buttonStyle(PressableButtonStyle())
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 80)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appPurple)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appPurple, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .principal) { EmptyView() } }
            .fullScreenCover(isPresented: $showSpeedRound) {
                SpeedRoundView()
            }
        }
        .background(Color.appPurple.ignoresSafeArea())
    }

    private var trainHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Train")
                    .font(.title2).fontWeight(.bold)
                    .foregroundStyle(.white)
                Text("Pick a module to practice")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            Text("🎸")
                .font(.system(size: 36))
        }
        .padding(.top, 4)
    }

    private var playAlongBanner: some View {
        NavigationLink { PlayAlongListView() } label: {
            HStack(spacing: 14) {
                Text("🎹")
                    .font(.system(size: 26))
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Play Along")
                            .font(.headline)
                            .foregroundStyle(TrainingModule.pastelText)
                        Text("NEW")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.appPurple).foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    Text("Play the melody on a MIDI keyboard or on screen")
                        .font(.caption).foregroundStyle(TrainingModule.pastelSubtext)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(TrainingModule.pastelSubtext)
            }
            .padding(14)
            .background(Color(red: 0.87, green: 0.96, blue: 0.92), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var speedRoundBanner: some View {
        Button { showSpeedRound = true } label: {
            HStack(spacing: 14) {
                Text("⚡")
                    .font(.system(size: 26))
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Speed Round")
                            .font(.headline)
                            .foregroundStyle(TrainingModule.pastelText)
                        Text("NEW")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.appPurple).foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    Text("60 seconds · Rapid-fire intervals · Earn bonus XP")
                        .font(.caption).foregroundStyle(TrainingModule.pastelSubtext)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(TrainingModule.pastelSubtext)
            }
            .padding(14)
            .background(Color(red: 1.00, green: 0.95, blue: 0.80), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressableButtonStyle())
    }

    @ViewBuilder
    private func moduleDestination(for module: TrainingModule) -> some View {
        if module.isProOnly && !storeManager.isPro {
            PaywallView()
        } else {
            switch module {
            case .intervalRecognition: IntervalModuleView()
            case .chordRecognition:    ChordModuleView()
            case .scaleRecognition:    ScaleModuleView()
            case .functionalEar:       FunctionalEarModuleView()
            case .melodicDictation:    MelodyDictationView()
            case .rhythmTrainer:       RhythmTrainerModuleView()
            case .chordProgressions:   ChordProgressionModuleView()
            case .singingPractice:     SingingPracticeModuleView()
            case .noteIdentification:  NoteIdentificationModuleView()
            case .chordInversions:     ChordInversionsModuleView()
            case .intervalComparison:  IntervalComparisonModuleView()
            case .errorDetection:      ErrorDetectionModuleView()
            case .relativePitch:       RelativePitchModuleView()
            case .absolutePitch:       AbsolutePitchModuleView()
            case .jazzChords:          JazzChordsModuleView()
            }
        }
    }
}

struct ModuleCard: View {
    let module: TrainingModule
    let isLocked: Bool
    var isComingSoon: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(module.moduleEmoji)
                    .font(.system(size: 28))
                Spacer()
                if isComingSoon {
                    Text("Soon")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.white.opacity(0.5))
                        .foregroundStyle(TrainingModule.pastelSubtext)
                        .clipShape(Capsule())
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(TrainingModule.pastelSubtext)
                        .padding(5)
                        .background(Color.white.opacity(0.5), in: Circle())
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(module.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isLocked ? TrainingModule.pastelSubtext : TrainingModule.pastelText)
                    .lineLimit(2)
                Text(module.description)
                    .font(.caption2)
                    .foregroundStyle(TrainingModule.pastelSubtext)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(
            isLocked || isComingSoon
                ? module.pastelColor.opacity(0.5)
                : module.pastelColor,
            in: RoundedRectangle(cornerRadius: 18)
        )
        .opacity(isComingSoon ? 0.65 : 1.0)
    }
}

struct ComingSoonView: View {
    let module: TrainingModule
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.purple.opacity(0.1)).frame(width: 100, height: 100)
                Image(systemName: module.systemImage)
                    .font(.system(size: 44)).foregroundStyle(Color.purple.opacity(0.5))
            }
            Text(module.rawValue).font(.title2).fontWeight(.bold)
            Text("Coming in EarIQ 1.1")
                .foregroundStyle(.secondary)
            Text("Interval, Chord, Scale, and Functional Ear are available now.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding()
        .navigationTitle(module.rawValue)
    }
}
