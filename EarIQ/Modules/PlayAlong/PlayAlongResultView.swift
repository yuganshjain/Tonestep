import SwiftUI
import SwiftData

struct PlayAlongResultView: View {
    let piece: LessonPiece
    let result: PlayAlongResult

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(piece.title)
                .font(.title2).fontWeight(.bold).foregroundStyle(.white)

            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < result.stars ? "star.fill" : "star")
                        .font(.system(size: 40))
                        .foregroundStyle(index < result.stars
                                         ? Color(red: 1, green: 0.85, blue: 0.2)
                                         : .white.opacity(0.3))
                }
            }

            Text("\(Int((result.accuracy * 100).rounded()))%")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 8) {
                row("Perfect", result.perfect, .green)
                row("Good", result.good, .mint)
                row("Late", result.late, .orange)
                row("Missed", result.missed, .red)
                row("Wrong notes", result.wrongNotes, .red)
            }
            .padding(16)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 32)

            Spacer()

            Button { dismiss() } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(Color.appPurple)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .background(Color.appPurple.ignoresSafeArea())
        .onAppear(perform: record)
    }

    private func row(_ label: String, _ value: Int, _ colour: Color) -> some View {
        HStack {
            Circle().fill(colour).frame(width: 8, height: 8)
            Text(label).font(.subheadline).foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text("\(value)").font(.subheadline).fontWeight(.semibold).foregroundStyle(.white)
        }
    }

    /// Feed the existing progress systems so streaks and XP keep working.
    private func record() {
        let drill = DrillResult(
            module: .melodicDictation,
            drillType: "playalong_\(piece.id)",
            wasCorrect: result.accuracy >= 0.8,
            responseTime: piece.duration
        )
        context.insert(drill)
        try? context.save()
    }
}
