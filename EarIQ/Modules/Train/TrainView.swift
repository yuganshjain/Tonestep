import SwiftUI

struct TrainView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @State private var showSpeedRound = false
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    speedRoundBanner
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(TrainingModule.allCases, id: \.self) { module in
                            NavigationLink { moduleDestination(for: module) } label: {
                                ModuleCard(module: module, isLocked: module.isProOnly && !storeManager.isPro)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Train")
            .navigationBarTitleDisplayMode(.large)
            .fullScreenCover(isPresented: $showSpeedRound) {
                SpeedRoundView()
            }
        }
    }

    private var speedRoundBanner: some View {
        Button { showSpeedRound = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [.purple, Color(red:0.6,green:0.1,blue:0.9)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                    Image(systemName: "timer")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Speed Round")
                            .font(.headline).foregroundStyle(.primary)
                        Text("NEW")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Color.purple).foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    Text("60 seconds · Rapid-fire intervals · Earn bonus XP")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.background, in: RoundedRectangle(cornerRadius: 18))
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
            default:                   ComingSoonView(module: module)
            }
        }
    }
}

struct ModuleCard: View {
    let module: TrainingModule
    let isLocked: Bool

    private var accentColor: Color {
        switch module {
        case .intervalRecognition: return Color(red: 0.4, green: 0.2, blue: 0.9)
        case .chordRecognition:    return Color(red: 0.2, green: 0.5, blue: 0.9)
        case .scaleRecognition:    return Color(red: 0.1, green: 0.7, blue: 0.5)
        case .functionalEar:       return Color(red: 0.8, green: 0.3, blue: 0.2)
        case .chordProgressions:   return Color(red: 0.6, green: 0.2, blue: 0.8)
        case .rhythmTrainer:       return Color(red: 0.9, green: 0.5, blue: 0.1)
        case .melodicDictation:    return Color(red: 0.2, green: 0.6, blue: 0.8)
        case .relativePitch:       return Color(red: 0.5, green: 0.7, blue: 0.2)
        case .absolutePitch:       return Color(red: 0.7, green: 0.5, blue: 0.1)
        case .singingPractice:     return Color(red: 0.9, green: 0.2, blue: 0.5)
        case .noteIdentification:  return Color(red: 0.1, green: 0.5, blue: 0.8)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(isLocked ? 0.08 : 0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: module.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isLocked ? .secondary : accentColor)
                }
                Spacer()
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(module.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isLocked ? .secondary : .primary)
                    .lineLimit(2)
                Text(module.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .background(
            isLocked ? Color(.secondarySystemBackground) : Color(.systemBackground),
            in: RoundedRectangle(cornerRadius: 18)
        )
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
