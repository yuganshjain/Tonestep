import SwiftUI
import SwiftData

struct DailySessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var userProfile: UserProfileStore
    @EnvironmentObject private var storeManager: StoreManager
    @Query private var allResults: [DrillResult]
    @Query private var srItems: [SRItem]

    @State private var plans: [DrillPlan] = []
    @State private var currentIndex = 0
    @State private var sessionRecord: DailySessionRecord?
    @State private var isComplete = false
    @State private var sessionXP = 0

    private var availableModules: [TrainingModule] {
        TrainingModule.allCases.filter { !$0.isProOnly || storeManager.isPro }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isComplete {
                    sessionCompleteView
                } else if plans.isEmpty {
                    ProgressView("Building your session…")
                        .onAppear { buildSession() }
                } else {
                    drillView
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Exit") { dismiss() }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Drill View

    @ViewBuilder
    private var drillView: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: Double(currentIndex), total: Double(plans.count))
                .tint(.purple)
                .padding()

            Text("\(currentIndex + 1) of \(plans.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)

            DrillDispatchView(drillType: plans[currentIndex].drillType) { correct, responseTime in
                recordResult(correct: correct, responseTime: responseTime)
            }
        }
    }

    // MARK: - Session Complete View

    private var sessionCompleteView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Session Complete!")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 8) {
                Text("+\(sessionXP) XP")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.purple)
                Text("Keep it up — come back tomorrow!")
                    .foregroundStyle(.secondary)
            }

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
        }
        .padding()
    }

    // MARK: - Logic

    private func buildSession() {
        let count = userProfile.sessionLength.rawValue / 1   // 1 drill ≈ 1 min approx
        plans = DailySessionBuilder.buildSession(
            srItems: srItems,
            recentResults: allResults,
            targetCount: min(max(count, 6), 12),
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
        if correct { sessionRecord?.correctDrills += 1 }

        let xp = correct ? 2 : 0
        sessionXP += xp
        userProfile.addXP(xp)

        if currentIndex + 1 >= plans.count {
            finishSession()
        } else {
            withAnimation { currentIndex += 1 }
        }
    }

    private func finishSession() {
        sessionRecord?.completedAt = Date()
        sessionRecord?.xpEarned = sessionXP
        userProfile.completeSession()
        sessionXP += 50  // session completion bonus
        withAnimation { isComplete = true }
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

/// Routes a drillType string to the correct exercise view.
struct DrillDispatchView: View {
    let drillType: String
    let onComplete: (Bool, TimeInterval) -> Void

    var body: some View {
        if drillType.hasPrefix("interval_") {
            IntervalDrillView(drillType: drillType, onComplete: onComplete)
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
