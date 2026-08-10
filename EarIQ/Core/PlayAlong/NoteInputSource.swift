import Foundation

protocol NoteInputSource: AnyObject {
    var onEvent: ((NoteEvent) -> Void)? { get set }
    func start()
    func stop()
}

/// Scripted source for unit tests. MIDI hardware does not exist in the Simulator,
/// so the engine is always tested through this.
final class FakeInputSource: NoteInputSource {
    var onEvent: ((NoteEvent) -> Void)?
    private var isRunning = false

    func start() { isRunning = true }
    func stop() { isRunning = false }

    func emit(_ event: NoteEvent) {
        guard isRunning else { return }
        onEvent?(event)
    }
}
