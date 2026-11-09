/// An individual pet's innate traits, each a score in 0...1. Rolled once at hatch time within the
/// species' `TraitRanges`, so two dogs feel related but never identical.
public struct PetTraits: Codable, Hashable, Sendable {
    /// Higher = gets hungry faster.
    public var appetite: Double
    /// Higher = gets bored (loses happiness) faster.
    public var playfulness: Double
    /// Higher = tires (loses energy) more slowly.
    public var stamina: Double
    /// Higher = stays clean longer.
    public var tidiness: Double

    public init(appetite: Double, playfulness: Double, stamina: Double, tidiness: Double) {
        self.appetite = appetite
        self.playfulness = playfulness
        self.stamina = stamina
        self.tidiness = tidiness
    }

    /// Multiplier applied to the base decay rate of `stat` (0.7×–1.3×).
    public func decayMultiplier(for stat: Stat) -> Double {
        switch stat {
        case .hunger: 0.7 + 0.6 * appetite
        case .happiness: 0.7 + 0.6 * playfulness
        case .energy: 1.3 - 0.6 * stamina
        case .cleanliness: 1.3 - 0.6 * tidiness
        }
    }
}

/// The allowed range for each trait within a species.
public struct TraitRanges: Codable, Hashable, Sendable {
    public var appetite: ClosedRange<Double>
    public var playfulness: ClosedRange<Double>
    public var stamina: ClosedRange<Double>
    public var tidiness: ClosedRange<Double>

    public init(
        appetite: ClosedRange<Double>,
        playfulness: ClosedRange<Double>,
        stamina: ClosedRange<Double>,
        tidiness: ClosedRange<Double>
    ) {
        self.appetite = appetite
        self.playfulness = playfulness
        self.stamina = stamina
        self.tidiness = tidiness
    }

    public func roll(using rng: inout some RandomNumberGenerator) -> PetTraits {
        PetTraits(
            appetite: .random(in: appetite, using: &rng),
            playfulness: .random(in: playfulness, using: &rng),
            stamina: .random(in: stamina, using: &rng),
            tidiness: .random(in: tidiness, using: &rng)
        )
    }

    public func contains(_ traits: PetTraits) -> Bool {
        appetite.contains(traits.appetite) && playfulness.contains(traits.playfulness)
            && stamina.contains(traits.stamina) && tidiness.contains(traits.tidiness)
    }

    var all: [ClosedRange<Double>] { [appetite, playfulness, stamina, tidiness] }
}
