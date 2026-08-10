import Foundation
import Combine

/// Owns a running lesson: the engine, the clock, the tick timer and the input
/// sources.
///
/// This is a reference type on purpose. An earlier version drove the timer from
/// `@State` inside the view, but the escaping timer closure captures a *copy* of
/// the View struct; writes through that stale copy update the storage without
/// reliably invalidating the view, so the note lane froze and the finish never
/// presented. An ObservableObject publishes properly.
final class PlayAlongSession: ObservableObject {

    @Published private(set) var now: TimeInterval = 0
    @Published private(set) var finished = false
    @Published private(set) var deviceName: String?

    let piece: LessonPiece
    let onScreen = OnScreenInputSource()

    private let clock: PlaybackClock
    private let countIn: TimeInterval
    private let midi = MIDIInputSource()
    private var engine: PlayAlongEngine?
    private var startTime: TimeInterval = 0
    private var timer: Timer?

    /// The clock deliberately does NOT start here. SwiftUI evaluates a
    /// NavigationLink's destination when the *list* renders, so constructing the
    /// session does not mean the lesson is on screen. Starting the count-in in
    /// init made the whole piece elapse before the user ever arrived, marking
    /// every note missed. Timing begins in start(), on appear.
    init(piece: LessonPiece, countIn: TimeInterval = 3, clock: PlaybackClock = SystemClock()) {
        self.piece = piece
        self.clock = clock
        self.countIn = countIn
    }

    var elapsed: TimeInterval { now - startTime }

    var judgements: [Judgement?] {
        engine?.judgements ?? Array(repeating: nil, count: piece.notes.count)
    }

    /// Notes due about now, highlighted on the keyboard as a hint.
    var expectedNow: Set<UInt8> {
        Set(piece.notes
            .filter { abs(piece.secondsForBeat($0.startBeat) - elapsed) < 0.35 }
            .map(\.midiNote))
    }

    /// Idempotent: onAppear can fire more than once.
    func start() {
        guard engine == nil else { return }

        startTime = clock.now + countIn
        now = clock.now
        let engine = PlayAlongEngine(piece: piece, startTime: startTime)
        self.engine = engine

        midi.onEvent = { [weak self] in self?.engine?.handle(event: $0) }
        onScreen.onEvent = { [weak self] in self?.engine?.handle(event: $0) }
        midi.start()
        onScreen.start()

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.step()
        }
        // .common so the tick survives scrolling and other tracking run-loop modes.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        midi.stop()
        onScreen.stop()
    }

    /// Lets the result cover be dismissed without immediately re-presenting.
    /// Safe because stop() has already invalidated the tick.
    func acknowledgeFinish() {
        finished = false
    }

    func result() -> PlayAlongResult {
        engine?.result() ?? PlayAlongResult(accuracy: 0, stars: 0, perfect: 0,
                                            good: 0, late: 0, missed: 0, wrongNotes: 0)
    }

    private func step() {
        guard let engine else { return }
        now = clock.now
        engine.update(now: now)
        if deviceName != midi.connectedDeviceName {
            deviceName = midi.connectedDeviceName
        }
        if engine.isFinished {
            stop()
            finished = true
        }
    }
}
