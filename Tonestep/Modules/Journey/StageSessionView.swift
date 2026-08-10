import SwiftUI
import SwiftData

/// Plays one curriculum stage: a fixed number of drills sampled from the
/// stage's DifficultyParams, then evaluated and persisted.
struct StageSessionView: View {
    let stage: Stage
    let entitlement: Entitlement

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var userProfile: UserProfileStore
    @Query private var progressRecords: [JourneyProgress]
    @Query private var stageRecords: [StageRecord]

    @State private var specs: [DrillSpec] = []
    @State private var index = 0
    @State private var results: [DrillResult] = []
    @State private var outcome: StageOutcome?

    var body: some View {
        ZStack {
            Color.appPurple.ignoresSafeArea()
            if let outcome {
                completeView(outcome)
            } else if index < specs.count {
                drillView
            } else {
                SwiftUI.ProgressView().tint(.white)
            }
        }
        .onAppear(perform: build)
    }

    private var drillView: some View {
        VStack(spacing: 0) {
            header
            DrillDispatchView(
                drillType: specs[index].drillType,
                spec: specs[index]
            ) { correct, responseTime in
                record(correct: correct, responseTime: responseTime)
            }
            .id(index)   // force a fresh drill view per question
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Text("\(index + 1) of \(specs.count)")
                    .font(.caption).foregroundStyle(.white.opacity(0.8))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.2))
                    Capsule().fill(Color.white)
                        .frame(width: geo.size.width * (Double(index) / Double(max(1, specs.count))))
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func completeView(_ outcome: StageOutcome) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Text(outcome.passed ? "Stage Complete" : "Not Quite")
                .font(.title).fontWeight(.bold).foregroundStyle(.white)
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < outcome.stars ? "star.fill" : "star")
                        .font(.system(size: 36))
                        .foregroundStyle(i < outcome.stars
                                         ? Color(red: 1, green: 0.85, blue: 0.2)
                                         : .white.opacity(0.3))
                }
            }
            Text("\(Int((outcome.accuracy * 100).rounded()))%")
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            if !outcome.passed {
                Text("Pass at \(Int(stage.passCriteria.minAccuracy * 100))% to unlock the next stage")
                    .font(.caption).foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Done").fontWeight(.semibold)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Color.appPurple)
            }
            .padding(.horizontal, 32).padding(.bottom, 32)
        }
    }

    // MARK: - Logic

    private func build() {
        guard specs.isEmpty else { return }
        specs = CurriculumBuilder.drillSpecs(
            for: stage,
            count: stage.passCriteria.minQuestions
        )
    }

    private func record(correct: Bool, responseTime: TimeInterval) {
        let spec = specs[index]
        let result = DrillResult(module: spec.module, drillType: spec.drillType,
                                 wasCorrect: correct, responseTime: responseTime)
        context.insert(result)
        results.append(result)

        // Keep spaced repetition fed, exactly as the daily session does.
        let quality = SREngine.quality(from: correct ? 1 : 0, responseTime: responseTime)
        let item = (try? context.fetch(FetchDescriptor<SRItem>()))?
            .first { $0.drillType == spec.drillType } ?? {
                let new = SRItem(drillType: spec.drillType)
                context.insert(new)
                return new
            }()
        SREngine.grade(for: item, quality: quality)

        // 2 XP per correct answer, matching DailySessionView's convention.
        if correct {
            userProfile.addXP(2)
            HapticsManager.success()
        } else {
            HapticsManager.error()
        }

        if index + 1 >= specs.count {
            finish()
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { index += 1 }
        }
    }

    private func finish() {
        let outcome = StageEvaluator.evaluate(results: results, criteria: stage.passCriteria)
        self.outcome = outcome

        let record = stageRecords.first { $0.stageId == stage.id } ?? {
            let new = StageRecord(stageId: stage.id)
            context.insert(new)
            return new
        }()
        record.record(outcome: outcome)

        if outcome.passed { advanceProgress() }
        try? context.save()
    }

    /// Move the journey marker forward only if this stage is the current one,
    /// so replaying an old stage cannot push the user backwards.
    private func advanceProgress() {
        let all = CurriculumBuilder.stages(for: entitlement)
        guard let progress = progressRecords.first,
              progress.currentStageId == stage.id,
              let position = all.firstIndex(where: { $0.id == stage.id }),
              position + 1 < all.count
        else { return }
        progress.advance(to: all[position + 1])
    }
}
