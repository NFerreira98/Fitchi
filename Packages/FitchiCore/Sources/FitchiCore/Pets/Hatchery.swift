import Foundation

public enum HatchError: Error, Equatable {
    case noSpeciesAvailable
}

/// Creates pets: the free random starter and pets hatched from eggs.
public enum Hatchery {
    /// The free starter egg: a random *common* species.
    public static func hatchStarter(
        from catalog: Catalog,
        at date: Date,
        using rng: inout some RandomNumberGenerator
    ) throws(HatchError) -> Pet {
        let commons = catalog.species.filter { $0.rarity == .common }
        guard let species = commons.randomElement(using: &rng) else { throw .noSpeciesAvailable }
        return makePet(species: species, at: date, using: &rng)
    }

    /// Hatches an egg: rolls a rarity using the egg's odds, then a species of that rarity.
    public static func hatch(
        _ egg: EggType,
        from catalog: Catalog,
        at date: Date,
        using rng: inout some RandomNumberGenerator
    ) throws(HatchError) -> Pet {
        let byRarity = Dictionary(grouping: catalog.species, by: \.rarity)
        let odds = egg.odds.filter { byRarity[$0.key]?.isEmpty == false }
        guard let rarity = rng.weightedPick(odds, order: Rarity.allCases),
            let species = byRarity[rarity]?.randomElement(using: &rng)
        else { throw .noSpeciesAvailable }
        return makePet(species: species, at: date, using: &rng)
    }

    /// Rolls a unique individual of `species`.
    public static func makePet(
        species: Species,
        name: String? = nil,
        at date: Date,
        using rng: inout some RandomNumberGenerator
    ) -> Pet {
        Pet(
            name: name ?? species.defaultNames.randomElement(using: &rng) ?? species.name,
            speciesID: species.id,
            traits: species.traitRanges.roll(using: &rng),
            personality: Personality.allCases.randomElement(using: &rng) ?? .easygoing,
            hatchedAt: date
        )
    }
}
