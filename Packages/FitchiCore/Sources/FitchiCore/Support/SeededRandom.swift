/// Deterministic random number generator (SplitMix64).
///
/// Use for anything that must be reproducible: tests, previews, and replaying a hatch from a stored seed.
/// Production code can pass `SystemRandomNumberGenerator` instead.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}

extension RandomNumberGenerator {
    /// Picks a key from `weights` proportionally to its weight, iterating keys in `order`.
    /// Returns nil when no key in `order` has a positive weight.
    mutating func weightedPick<Key: Hashable>(_ weights: [Key: Double], order: [Key]) -> Key? {
        let candidates = order.filter { (weights[$0] ?? 0) > 0 }
        let total = candidates.reduce(0) { $0 + (weights[$1] ?? 0) }
        guard total > 0 else { return nil }
        var roll = Double.random(in: 0..<total, using: &self)
        for key in candidates {
            let weight = weights[key] ?? 0
            if roll < weight { return key }
            roll -= weight
        }
        return candidates.last
    }
}
