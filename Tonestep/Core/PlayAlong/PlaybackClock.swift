import Foundation
import QuartzCore

protocol PlaybackClock: AnyObject {
    var now: TimeInterval { get }
}

/// CACurrentMediaTime is monotonic and unaffected by wall-clock changes,
/// which Date is not.
final class SystemClock: PlaybackClock {
    var now: TimeInterval { CACurrentMediaTime() }
}

/// Deterministic clock so timing tests never depend on wall time.
final class FakeClock: PlaybackClock {
    var now: TimeInterval = 0
    func advance(by delta: TimeInterval) { now += delta }
}
