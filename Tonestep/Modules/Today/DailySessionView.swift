import SwiftUI
import SwiftData

struct DailySessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var userProfile: UserProfileStore
    @EnvironmentObject private var storeManager: StoreManager
    @Query(sort: \DrillResult.timestamp, order: .reverse) private var allResults: [DrillResult]
    @Query(sort: \SRItem.nextReviewDate) private var srItems: [SRItem]

    @State private var plans: [DrillPlan] = []
    @State private var currentIndex = 0
    @State private var sessionRecord: DailySessionRecord?
    @State private var isComplete = false
    @State private var sessionXP = 0
    @State private var correctCount = 0
    @State private var showExitAlert = false

    private var availableModules: [TrainingModule] {
        TrainingModule.allCases.filter { !$0.isProOnly || storeManager.isPro }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isComplete {
                    sessionCompleteView
                } else if plans.isEmpty {
                    buildingView
                } else {
                    drillView
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if plans.isEmpty || isComplete { dismiss() }
                        else { showExitAlert = true }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Exit Session?", isPresented: $showExitAlert) {
            Button("Continue Training", role: .cancel) {}
            Button("Exit", role: .destructive) { dismiss() }
        } message: {
            Text("Your progress so far will be saved.")
        }
        .interactiveDismissDisabled(!isComplete)
    }

    // MARK: - Building View

    private var buildingView: some View {
        VStack(spacing: 20) {
            SwiftUI.ProgressView()
                .scaleEffect(1.4)
                .tint(Color.purple)
            Text("Building your session…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .onAppear { buildSession() }
    }

    // MARK: - Drill View

    private var drillView: some View {
        VStack(spacing: 0) {
            sessionProgressBar
            DrillDispatchView(drillType: plans[currentIndex].drillType,
                              spec: plans[currentIndex].spec) { correct, responseTime in
                recordResult(correct: correct, responseTime: responseTime)
            }
        }
    }

    private var sessionProgressBar: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(currentIndex + 1) of \(plans.count)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(correctCount) correct")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemFill))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.purple)
                        .frame(width: geo.size.width * (Double(currentIndex) / Double(plans.count)))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
                }
            }
            .frame(height: 6)
            .padding(.horizontal)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Session Complete

    private var sessionCompleteView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                }
                .transition(.scale.combined(with: .opacity))

                Text("Session Complete!")
                    .font(.largeTitle).fontWeight(.bold)

                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text("\(plans.count)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("Drills")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Rectangle().frame(width: 1, height: 40).foregroundStyle(.secondary.opacity(0.3))
                    VStack(spacing: 4) {
                        Text("\(correctCount)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                        Text("Correct")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Rectangle().frame(width: 1, height: 40).foregroundStyle(.secondary.opacity(0.3))
                    VStack(spacing: 4) {
                        Text("+\(sessionXP)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.purple)
                        Text("XP")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            }

            Spacer()

            Button { dismiss() } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .transition(.opacity)
    }

    // MARK: - Logic

    private func buildSession() {
        let count = max(6, min(userProfile.sessionLength.rawValue, 12))
        plans = DailySessionBuilder.buildSession(
            srItems: srItems,
            recentResults: allResults,
            targetCount: count,
            isPro: storeManager.isPro,
            availableModules: availableModules
        )
        let record = DailySessionRecord()
        context.insert(record)
        sessionRecord = record
    }

    private func recordResult(correct: Bool, responseTime: TimeInterval) {
        guard currentIndex < plans.count else { return }
        let plan = plans[currentIndex]
        let result = DrillResult(
            module: moduleFor(drillType: plan.drillType),
            drillType: plan.drillType,
            wasCorrect: correct,
            responseTime: responseTime
        )
        context.insert(result)
        sessionRecord?.totalDrills += 1
        if correct {
            sessionRecord?.correctDrills += 1
            correctCount += 1
            HapticsManager.success()
        } else {
            HapticsManager.error()
        }

        let xp = correct ? 2 : 0
        sessionXP += xp
        userProfile.addXP(xp)

        if currentIndex + 1 >= plans.count {
            finishSession()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { currentIndex += 1 }
        }
    }

    private func finishSession() {
        sessionRecord?.completedAt = Date()
        sessionRecord?.xpEarned = sessionXP
        userProfile.completeSession()
        sessionXP += 50
        HapticsManager.heavyImpact()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { isComplete = true }
    }

    private func moduleFor(drillType: String) -> TrainingModule {
        if drillType.hasPrefix("interval_") { return .intervalRecognition }
        if drillType.hasPrefix("chord_") { return .chordRecognition }
        if drillType.hasPrefix("scale_") { return .scaleRecognition }
        if drillType.hasPrefix("functional_") { return .functionalEar }
        return .intervalRecognition
    }
}

// MARK: - Drill Dispatcher

struct DrillDispatchView: View {
    let drillType: String
    /// When supplied, routing uses spec.module and the exact drill is rendered.
    var spec: DrillSpec? = nil
    let onComplete: (Bool, TimeInterval) -> Void

    var body: some View {
        if let spec {
            switch spec.module {
            case .chordRecognition:
                ChordDrillView(drillType: drillType, spec: spec, onComplete: onComplete)
            case .scaleRecognition:
                ScaleDrillView(drillType: drillType, spec: spec, onComplete: onComplete)
            case .functionalEar:
                FunctionalEarDrillView(drillType: drillType, spec: spec, onComplete: onComplete)
            default:
                IntervalDrillView(drillType: drillType, spec: spec, onComplete: onComplete)
            }
        } else if drillType.hasPrefix("chord_") {
            ChordDrillView(drillType: drillType, onComplete: onComplete)
        } else if drillType.hasPrefix("scale_") {
            ScaleDrillView(drillType: drillType, onComplete: onComplete)
        } else if drillType.hasPrefix("functional_") {
            FunctionalEarDrillView(drillType: drillType, onComplete: onComplete)
        } else {
            IntervalDrillView(drillType: drillType, onComplete: onComplete)
        }
    }
}

// MARK: - Haptics

enum HapticsManager {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    static func impact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func heavyImpact() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
