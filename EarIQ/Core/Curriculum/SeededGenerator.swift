import Foundation

/// xorshift64. Reproducible across runs and platforms, unlike SystemRandomNumberGenerator.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        // xorshift breaks down at zero.
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// FNV-1a. String.hashValue is randomly seeded per process, so it cannot be
    /// used anywhere determinism is required.
    static func seed(from string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
