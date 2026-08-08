import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var userProfile: UserProfileStore
    @State private var page = 0
    @State private var selectedGoal: LearningGoal?
    @State private var selectedInstrument: Instrument?

    var body: some View {
        VStack(spacing: 0) {
            if page == 0 {
                goalPage
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else {
                instrumentPage
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: page)
    }

    // MARK: - Page 1: Goal

    private var goalPage: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 8) {
                Text("🎵")
                    .font(.system(size: 56))
                Text("Welcome to EarIQ")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("What's your main goal?")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(LearningGoal.allCases, id: \.self) { goal in
                    Button {
                        selectedGoal = goal
                    } label: {
                        HStack {
                            Text(goal.rawValue)
                                .font(.subheadline)
                            Spacer()
                            if selectedGoal == goal {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.purple)
                            }
                        }
                        .padding()
                        .background(selectedGoal == goal ? Color.purple.opacity(0.1) : Color(.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(selectedGoal == goal ? Color.purple : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Button {
                withAnimation { page = 1 }
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectedGoal != nil ? Color.purple : Color(.systemFill))
                    .foregroundStyle(selectedGoal != nil ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .fontWeight(.semibold)
            }
            .disabled(selectedGoal == nil)
        }
        .padding(24)
    }

    // MARK: - Page 2: Instrument

    private var instrumentPage: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 8) {
                Text("What do you play?")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("EarIQ uses your instrument for playback sounds.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Instrument.allCases, id: \.self) { instrument in
                    Button {
                        selectedInstrument = instrument
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: instrument.systemImage)
                                .font(.title)
                                .foregroundStyle(selectedInstrument == instrument ? .white : .purple)
                            Text(instrument.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(selectedInstrument == instrument ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(selectedInstrument == instrument ? Color.purple : Color(.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            Button {
                finishOnboarding()
            } label: {
                Text("Start Training")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(selectedInstrument != nil ? Color.purple : Color(.systemFill))
                    .foregroundStyle(selectedInstrument != nil ? .white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .fontWeight(.semibold)
            }
            .disabled(selectedInstrument == nil)
        }
        .padding(24)
    }

    private func finishOnboarding() {
        if let goal = selectedGoal { userProfile.learningGoal = goal }
        if let instrument = selectedInstrument { userProfile.instrument = instrument }
        withAnimation { userProfile.hasCompletedOnboarding = true }
    }
}
