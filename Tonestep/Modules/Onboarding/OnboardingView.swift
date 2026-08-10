import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var userProfile: UserProfileStore
    @State private var page = 0
    @State private var selectedGoal: LearningGoal?
    @State private var selectedInstrument: Instrument?

    var body: some View {
        ZStack {
            // Full-screen gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.04, blue: 0.20),
                    Color(red: 0.22, green: 0.06, blue: 0.42),
                    Color(red: 0.38, green: 0.10, blue: 0.62),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(.all)

            // Page dots
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    ForEach(0..<2, id: \.self) { i in
                        Capsule()
                            .fill(page == i ? Color.white : Color.white.opacity(0.3))
                            .frame(width: page == i ? 20 : 8, height: 8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: page)
                    }
                }
                .padding(.bottom, 40)
            }

            // Page content
            if page == 0 {
                goalPage
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                instrumentPage
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: page)
    }

    // MARK: - Goal Page

    private var goalPage: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: geo.safeAreaInsets.top + 24)

                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 80, height: 80)
                            Text("🎵")
                                .font(.system(size: 44))
                        }

                        VStack(spacing: 6) {
                            Text("Welcome to Tonestep")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("What's your main goal?")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }

                    Spacer().frame(height: 32)

                    VStack(spacing: 10) {
                        ForEach(LearningGoal.allCases, id: \.self) { goal in
                            OnboardingOptionRow(
                                title: goal.rawValue,
                                isSelected: selectedGoal == goal,
                                action: { selectedGoal = goal }
                            )
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 32)

                    Button {
                        withAnimation { page = 1 }
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                selectedGoal != nil
                                ? Color.white
                                : Color.white.opacity(0.25)
                            )
                            .foregroundStyle(
                                selectedGoal != nil
                                ? Color(red: 0.3, green: 0.05, blue: 0.55)
                                : Color.white.opacity(0.6)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .fontWeight(.semibold)
                            .animation(.easeInOut(duration: 0.2), value: selectedGoal)
                    }
                    .disabled(selectedGoal == nil)
                    .padding(.horizontal, 24)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 48)
                }
                .frame(minHeight: geo.size.height)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Instrument Page

    private var instrumentPage: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: geo.safeAreaInsets.top + 24)

                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 80, height: 80)
                            Text("🎹").font(.system(size: 44))
                        }

                        VStack(spacing: 6) {
                            Text("What do you play?")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Tonestep uses your instrument for playback sounds")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }

                    Spacer().frame(height: 32)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(Instrument.allCases, id: \.self) { instrument in
                            InstrumentCard(
                                instrument: instrument,
                                isSelected: selectedInstrument == instrument,
                                action: { selectedInstrument = instrument }
                            )
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 32)

                    Button { finishOnboarding() } label: {
                        Text("Start Training")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                selectedInstrument != nil
                                ? Color.white
                                : Color.white.opacity(0.25)
                            )
                            .foregroundStyle(
                                selectedInstrument != nil
                                ? Color(red: 0.3, green: 0.05, blue: 0.55)
                                : Color.white.opacity(0.6)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .fontWeight(.semibold)
                            .animation(.easeInOut(duration: 0.2), value: selectedInstrument)
                    }
                    .disabled(selectedInstrument == nil)
                    .padding(.horizontal, 24)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 48)
                }
                .frame(minHeight: geo.size.height)
            }
        }
        .ignoresSafeArea()
    }

    private func finishOnboarding() {
        if let goal = selectedGoal { userProfile.learningGoal = goal }
        if let instrument = selectedInstrument { userProfile.instrument = instrument }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            userProfile.hasCompletedOnboarding = true
        }
    }
}

// MARK: - Sub-components

struct OnboardingOptionRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color(red: 0.3, green: 0.05, blue: 0.55) : .white)
                Spacer()
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 12, height: 12)
                            .transition(.scale)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                isSelected ? Color.white : Color.white.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct InstrumentCard: View {
    let instrument: Instrument
    let isSelected: Bool
    let action: () -> Void

    private var emoji: String {
        switch instrument {
        case .piano:  return "🎹"
        case .guitar: return "🎸"
        case .bass:   return "🎸"
        case .violin: return "🎻"
        case .voice:  return "🎤"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Text(emoji).font(.system(size: 36))
                Text(instrument.rawValue)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color(red: 0.3, green: 0.05, blue: 0.55) : .white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                isSelected ? Color.white : Color.white.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.clear : Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
