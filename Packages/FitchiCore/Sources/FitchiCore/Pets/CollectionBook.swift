import Foundation

/// One thing to collect: a species in one colouring (or its only look, for species without
/// variants), or its shiny.
public struct CollectionEntry: Hashable, Sendable, Identifiable {
    public var speciesID: String
    /// nil for species without colour variants.
    public var variantID: String?
    /// "Ginger", or the species name when it has no variants.
    public var name: String
    public var rarity: Rarity
    public var isShiny: Bool
    /// When the first pet matching this entry hatched; nil while undiscovered.
    public var foundAt: Date?

    public var id: String { "\(speciesID)/\(variantID ?? "-")" }
    public var isFound: Bool { foundAt != nil }

    /// The variant to draw this entry with.
    public var variant: PetVariant? { variantID.map { PetVariant(id: $0, isShiny: isShiny) } }
}

/// The player's collection, Pokédex-style: every species and colouring in the catalog, marked
/// found once the player has owned one. Pets never leave the roster (even ones that ran away),
/// so the book only fills up.
public struct CollectionBook: Hashable, Sendable {
    /// Grouped by species, in catalog order sorted by rarity (commons first).
    public private(set) var species: [Page]

    public struct Page: Hashable, Sendable, Identifiable {
        public var species: Species
        public var entries: [CollectionEntry]

        public var id: String { species.id }
        public var foundCount: Int { entries.count(where: \.isFound) }
        /// Found at least one colouring: the species' name and look are revealed.
        public var isDiscovered: Bool { foundCount > 0 }
    }

    public init(catalog: Catalog, pets: [Pet]) {
        var firstFound: [String: Date] = [:]
        for pet in pets {
            guard let species = catalog.species(id: pet.speciesID) else { continue }
            // Pets from before variants existed count as the colouring they're drawn with.
            let colouring = species.colorVariant(for: pet.variant)
            let key = Self.key(species.id, colouring?.id)
            firstFound[key] = min(firstFound[key] ?? pet.hatchedAt, pet.hatchedAt)
        }
        species = catalog.species
            .enumerated()
            .sorted { ($0.element.rarity, $0.offset) < ($1.element.rarity, $1.offset) }
            .map(\.element)
            .map { species in
                var entries =
                    species.variants.isEmpty
                    ? [Self.entry(species, variant: nil, shiny: false, found: firstFound)]
                    : species.variants.map { Self.entry(species, variant: $0, shiny: false, found: firstFound) }
                if let shiny = species.shiny {
                    entries.append(Self.entry(species, variant: shiny, shiny: true, found: firstFound))
                }
                return Page(species: species, entries: entries)
            }
    }

    public var entries: [CollectionEntry] { species.flatMap(\.entries) }
    public var foundCount: Int { entries.count(where: \.isFound) }
    public var totalCount: Int { entries.count }
    public var shiniesFound: Int { entries.count { $0.isShiny && $0.isFound } }

    private static func key(_ speciesID: String, _ variantID: String?) -> String {
        "\(speciesID)/\(variantID ?? "-")"
    }

    private static func entry(
        _ species: Species, variant: ColorVariant?, shiny: Bool, found: [String: Date]
    ) -> CollectionEntry {
        CollectionEntry(
            speciesID: species.id, variantID: variant?.id, name: variant?.name ?? species.name, rarity: species.rarity,
            isShiny: shiny, foundAt: found[key(species.id, variant?.id)])
    }
}
