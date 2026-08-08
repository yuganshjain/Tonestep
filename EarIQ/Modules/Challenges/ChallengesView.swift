import SwiftUI

struct ChallengesView: View {
    @EnvironmentObject private var storeManager: StoreManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if storeManager.isPro {
                        weeklyChallengeCard
                    } else {
                        ProTeaser(
                            title: "Weekly Challenges",
                            description: "Compete on a fixed weekly set of 20 questions. Same questions for all users — see how you rank.",
                            icon: "trophy.fill"
                        )
                    }
                    personalBestsCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Challenges")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var weeklyChallengeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(.yellow)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Challenge")
                        .font(.headline)
                    Text("Resets Sunday midnight")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Button {
                // TODO: navigate to challenge session
            } label: {
                Text("Start This Week's Challenge")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.yellow)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var personalBestsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Bests")
                .font(.headline)
            ForEach(TrainingModule.allCases.prefix(4), id: \.self) { module in
                HStack {
                    Image(systemName: module.systemImage)
                        .foregroundStyle(.purple)
                        .frame(width: 22)
                    Text(module.rawValue)
                        .font(.subheadline)
                    Spacer()
                    Text("—")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            Text("Complete sessions to set your personal bests.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}
