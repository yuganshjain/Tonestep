import SwiftUI

struct PlayAlongView: View {
    let piece: LessonPiece

    @StateObject private var session: PlayAlongSession
    @Environment(\.dismiss) private var dismiss

    /// How far ahead of the judgement line the lane shows.
    private let lookAhead: TimeInterval = 3.0

    init(piece: LessonPiece) {
        self.piece = piece
        _session = StateObject(wrappedValue: PlayAlongSession(piece: piece))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            noteLane
            PianoKeyboardView(lowestNote: 60, octaves: 2,
                              highlighted: session.expectedNow, source: session.onScreen)
                .frame(height: 130)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .background(Color.appPurple.ignoresSafeArea())
        .onAppear { session.start() }
        .onDisappear { session.stop() }
        // A real two-way binding: .constant() would leave the cover undismissable.
        .fullScreenCover(isPresented: Binding(
            get: { session.finished },
            set: { presented in
                guard !presented else { return }
                session.acknowledgeFinish()
                dismiss()   // pop back to the piece list
            }
        )) {
            PlayAlongResultView(piece: piece, result: session.result())
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(piece.title)
                .font(.headline).foregroundStyle(.white)
            Text(session.deviceName ?? "Using on-screen keyboard")
                .font(.caption).foregroundStyle(.white.opacity(0.7))
            if session.elapsed < 0 {
                Text("Starting in \(max(1, Int(ceil(-session.elapsed))))…")
                    .font(.caption).fontWeight(.semibold)
                    .foregroundStyle(.white)
            } else {
                Text("Scored on when you press, not how long you hold.")
                    .font(.caption2).foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.vertical, 12)
    }

    /// Notes fall toward a fixed judgement line near the bottom.
    private var noteLane: some View {
        GeometryReader { geo in
            let lineY = geo.size.height * 0.86
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(height: 2)
                    .offset(y: lineY)

                ForEach(Array(piece.notes.enumerated()), id: \.offset) { index, note in
                    let due = piece.secondsForBeat(note.startBeat)
                    let delta = due - session.elapsed
                    if delta < lookAhead && delta > -0.6 {
                        let progress = 1 - (delta / lookAhead)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(colour(for: session.judgements[index]))
                            .frame(width: 38,
                                   height: max(18, CGFloat(note.durationBeats) * 22))
                            .position(
                                x: xPosition(for: note.midiNote, width: geo.size.width),
                                y: lineY * CGFloat(progress)
                            )
                    }
                }
            }
        }
    }

    private func colour(for judgement: Judgement?) -> Color {
        switch judgement {
        case .perfect: return .green
        case .good:    return .mint
        case .late:    return .orange
        case .missed:  return .red.opacity(0.6)
        case nil:      return .white.opacity(0.9)
        }
    }

    private func xPosition(for midiNote: UInt8, width: CGFloat) -> CGFloat {
        let lowest = piece.notes.map(\.midiNote).min() ?? 60
        let highest = piece.notes.map(\.midiNote).max() ?? 72
        let span = max(1, Int(highest) - Int(lowest))
        let t = CGFloat(Int(midiNote) - Int(lowest)) / CGFloat(span)
        return 30 + t * (width - 60)
    }
}

/// Entry point: pick a piece. Keeps Play-Along reachable from the Train tab.
struct PlayAlongListView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(LessonLibrary.all) { piece in
                    NavigationLink {
                        PlayAlongView(piece: piece)
                    } label: {
                        HStack(spacing: 14) {
                            Text("🎹").font(.system(size: 28))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(piece.title)
                                    .font(.headline)
                                    .foregroundStyle(TrainingModule.pastelText)
                                Text("\(piece.notes.count) notes · \(Int(piece.bpm)) bpm")
                                    .font(.caption)
                                    .foregroundStyle(TrainingModule.pastelSubtext)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(TrainingModule.pastelSubtext)
                        }
                        .padding(14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding()
        }
        .scrollContentBackground(.hidden)
        .background(Color.appPurple)
        .navigationTitle("Play Along")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appPurple, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}
