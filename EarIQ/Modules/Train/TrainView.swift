import SwiftUI

struct TrainView: View {
    @EnvironmentObject private var storeManager: StoreManager

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(TrainingModule.allCases, id: \.self) { module in
                        NavigationLink {
                            moduleDestination(for: module)
                        } label: {
                            ModuleCard(module: module, isLocked: module.isProOnly && !storeManager.isPro)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Train")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private func moduleDestination(for module: TrainingModule) -> some View {
        if module.isProOnly && !storeManager.isPro {
            PaywallView()
        } else {
            switch module {
            case .intervalRecognition:  IntervalModuleView()
            case .chordRecognition:     ChordModuleView()
            case .scaleRecognition:     ScaleModuleView()
            case .functionalEar:        FunctionalEarModuleView()
            default:
                ComingSoonView(module: module)
            }
        }
    }
}

struct ModuleCard: View {
    let module: TrainingModule
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: module.systemImage)
                    .font(.title2)
                    .foregroundStyle(isLocked ? .secondary : .purple)
                Spacer()
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(module.rawValue)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(isLocked ? .secondary : .primary)
                Text(module.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(isLocked ? Color(.secondarySystemBackground) : Color(.systemBackground),
                    in: RoundedRectangle(cornerRadius: 16))
    }
}

struct ComingSoonView: View {
    let module: TrainingModule
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: module.systemImage)
                .font(.system(size: 60))
                .foregroundStyle(.purple.opacity(0.5))
            Text(module.rawValue)
                .font(.title2)
                .fontWeight(.bold)
            Text("Coming in EarIQ 1.1")
                .foregroundStyle(.secondary)
        }
        .navigationTitle(module.rawValue)
    }
}
