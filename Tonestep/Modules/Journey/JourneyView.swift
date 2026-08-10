import SwiftUI
import SwiftData

struct JourneyView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.modelContext) private var context
    @Query private var progressRecords: [JourneyProgress]
    @Query private var stageRecords: [StageRecord]
    @Query private var allResults: [DrillResult]

    @State private var selectedStage: Stage?

    private var entitlement: Entitlement { storeManager.isPro ? .pro : .free }
    private var chapters: [Chapter] { CurriculumBuilder.chapters(for: entitlement) }
    private var stages: [Stage] { CurriculumBuilder.stages(for: entitlement) }
    private var currentStageId: String? { progressRecords.first?.currentStageId }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                ForEach(chapters) { chapter in
                    chapterSection(chapter)
                }
            }
            .padding()
            .padding(.bottom, 90)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appPurple)
        .navigationTitle("Journey")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appPurple, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear(perform: seedProgressIfNeeded)
        .fullScreenCover(item: $selectedStage) { stage in
            StageSessionView(stage: stage, entitlement: entitlement)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your Journey")
                .font(.title2).fontWeight(.bold).foregroundStyle(.white)
            Text("\(passedCount) of \(stages.count) stages complete")
                .font(.caption).foregroundStyle(.white.opacity(0.7))
        }
    }

    private func chapterSection(_ chapter: Chapter) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.title)
                    .font(.headline).foregroundStyle(.white)
                Text(chapter.subtitle)
                    .font(.caption).foregroundStyle(.white.opacity(0.65))
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                      spacing: 10) {
                ForEach(0..<chapter.stageCount, id: \.self) { index in
                    stageBubble(chapterId: chapter.id, index: index)
                }
            }
        }
    }

    private func stageBubble(chapterId: String, index: Int) -> some View {
        let id = "\(chapterId)-\(index)"
        let record = stageRecords.first { $0.stageId == id }
        let isPassed = record?.passedAt != nil
        let isCurrent = currentStageId == id
        let isLocked = !isPassed && !isCurrent

        return Button {
            guard !isLocked, let stage = stages.first(where: { $0.id == id }) else { return }
            selectedStage = stage
        } label: {
            VStack(spacing: 3) {
                Text("\(index + 1)")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundStyle(isLocked ? .white.opacity(0.45)
                                     : (isCurrent ? .white : TrainingModule.pastelText))
                if isPassed {
                    HStack(spacing: 1) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < (record?.stars ?? 0) ? "star.fill" : "star")
                                .font(.system(size: 6))
                                .foregroundStyle(Color(red: 1, green: 0.75, blue: 0.1))
                        }
                    }
                } else if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8)).foregroundStyle(.white.opacity(0.45))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(bubbleBackground(isPassed: isPassed, isCurrent: isCurrent),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isCurrent ? Color.white : .clear, lineWidth: 2)
            )
        }
        .disabled(isLocked)
        .buttonStyle(PressableButtonStyle())
    }

    private func bubbleBackground(isPassed: Bool, isCurrent: Bool) -> Color {
        if isPassed { return Color(red: 0.80, green: 0.95, blue: 0.85) }
        if isCurrent { return Color.white.opacity(0.28) }
        return Color.white.opacity(0.10)
    }

    private var passedCount: Int {
        stageRecords.filter { $0.passedAt != nil }.count
    }

    /// Place an existing user at a sensible stage from their drill history
    /// rather than resetting them to stage 1.
    private func seedProgressIfNeeded() {
        guard progressRecords.isEmpty else { return }
        let start = JourneySeeder.inferStartingStage(from: allResults, entitlement: entitlement)
        context.insert(JourneyProgress(currentChapterId: start.chapterId,
                                       currentIndexInChapter: start.indexInChapter))
        try? context.save()
    }
}
