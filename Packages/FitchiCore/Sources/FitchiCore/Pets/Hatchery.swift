import Foundation

public enum HatchError: Error, Equatable {
    case noSpeciesAvailable
}

/// Creates pets: the free random starter and pets hatched from eggs.
public enum Hatchery {
    /// The free starter egg: a random *common* species (favouring any that like the moment).
    /// - Parameter moment: the season, weather and time it hatches in (`HatchMoment(at:)`).
    public static func hatchStarter(
        from catalog: Catalog,
        at date: Date,
        moment: HatchMoment = .plain,
        rules: HatchRules = .v1,
        variants: VariantRules = .v1,
        using rng: inout some RandomNumberGenerator
    ) throws(HatchError) -> Pet {
        let commons = catalog.species.filter { $0.rarity == .common }
        let weights = Dictionary(commons.map { ($0.id, $0.affinity(at: moment)) }, uniquingKeysWith: +)
        guard let id = rng.weightedPick(weights, order: commons.map(\.id)),
            let species = commons.first(where: { $0.id == id })
        else { throw .noSpeciesAvailable }
        return makePet(
            species: species, at: date, initialValue: rules.newbornStatValue,
            variant: variants.roll(for: species, at: moment, using: &rng), using: &rng)
    }

    /// Hatches an egg: rolls a rarity using the egg's odds, then a species and colouring of that
    /// rarity. Within the rarity, colourings missing from `history` are favoured and, after
    /// `pityAfter` repeats in a row, guaranteed (when any are left). Shinies keep their own odds.
    public static func hatch(
        _ egg: EggType,
        from catalog: Catalog,
        at date: Date,
        history: HatchHistory = .empty,
        duplicates: DuplicateRules = .v1,
        variants: VariantRules = .v1,
        moment: HatchMoment = .plain,
        using rng: inout some RandomNumberGenerator
    ) throws(HatchError) -> Pet {
        let byRarity = Dictionary(grouping: catalog.species, by: \.rarity)
        let odds = egg.odds.filter { byRarity[$0.key]?.isEmpty == false }
        guard let rarity = rng.weightedPick(odds, order: Rarity.allCases), let pool = byRarity[rarity] else {
            throw .noSpeciesAvailable
        }
        // A shiny: the same 1-in-64 as always, for any species of the rarity.
        if Double.random(in: 0..<1, using: &rng) < variants.shinyChance,
            let species = pool.filter({ $0.shiny != nil }).randomElement(using: &rng), let shiny = species.shiny
        {
            return makePet(species: species, at: date, variant: PetVariant(id: shiny.id, isShiny: true), using: &rng)
        }
        let candidates = colourings(of: pool, at: moment)
        let fresh = candidates.filter { !history.found.contains($0.id) }
        let pityPool = history.repeatsInARow >= duplicates.pityAfter && !fresh.isEmpty ? fresh : candidates
        var weights: [String: Double] = [:]
        for candidate in pityPool {
            let boost = history.found.contains(candidate.id) ? 1 : duplicates.newFindBoost
            weights[candidate.id] = candidate.weight * boost
        }
        guard let pickedID = rng.weightedPick(weights, order: pityPool.map(\.id)),
            let picked = pityPool.first(where: { $0.id == pickedID })
        else { throw .noSpeciesAvailable }
        return makePet(species: picked.species, at: date, variant: picked.variant, using: &rng)
    }

    /// Every colouring in `pool` that can hatch at `moment` (regular ones, plus special ones whose
    /// condition holds). Each species gets an equal share of the rarity, scaled by its affinity
    /// for the moment; its colourings keep their relative weights (as before duplicate protection).
    private static func colourings(of pool: [Species], at moment: HatchMoment) -> [Colouring] {
        let affinity = pool.reduce(0) { $0 + $1.affinity(at: moment) }
        return pool.flatMap { species -> [Colouring] in
            let share = species.affinity(at: moment) / max(affinity, .leastNonzeroMagnitude)
            let open = species.variants(at: moment)
            guard !open.isEmpty else {
                return [Colouring(species: species, variant: nil, weight: share)]
            }
            let total = open.reduce(0) { $0 + $1.weight }
            return open.map { colouring in
                Colouring(
                    species: species, variant: PetVariant(id: colouring.id),
                    weight: share * colouring.weight / max(total, .leastNonzeroMagnitude))
            }
        }
    }

    private struct Colouring {
        var species: Species
        var variant: PetVariant?
        var weight: Double
        var id: String { species.collectionID(for: variant) }
    }

    /// Rolls a unique individual of `species` (in `chosen` colouring, if given).
    public static func makePet(
        species: Species,
        name: String? = nil,
        at date: Date,
        initialValue: Double = 80,
        variants: VariantRules = .v1,
        variant chosen: PetVariant? = nil,
        using rng: inout some RandomNumberGenerator
    ) -> Pet {
        let name = name ?? species.defaultNames.randomElement(using: &rng) ?? species.name
        let traits = species.traitRanges.roll(using: &rng)
        let personality = Personality.allCases.randomElement(using: &rng) ?? .easygoing
        return Pet(
            name: name,
            speciesID: species.id,
            traits: traits,
            personality: personality,
            hatchedAt: date,
            variant: chosen ?? variants.roll(for: species, using: &rng),
            initialValue: initialValue
        )
    }
}
