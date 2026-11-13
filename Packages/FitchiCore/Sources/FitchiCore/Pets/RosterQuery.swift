import Foundation

/// What kind of colouring a pet has, for filtering.
public enum ColouringKind: String, CaseIterable, Codable, Sendable {
    case regular
    /// Only hatches in certain weather, at a certain time or in a certain season.
    case special
    case shiny
}

extension Catalog {
    /// The colouring a pet is drawn in (pets from before variants count as the species' first).
    public func colouring(of pet: Pet) -> ColorVariant? {
        species(id: pet.speciesID)?.colorVariant(for: pet.variant)
    }

    public func colouringKind(of pet: Pet) -> ColouringKind {
        if pet.isShiny { return .shiny }
        return colouring(of: pet)?.when != nil ? .special : .regular
    }
}

/// Searching, filtering, sorting and grouping the pets you own. Pure, so the phone's Pets tab
/// stays simple and the rules are tested.
public struct RosterQuery: Hashable, Sendable {
    public enum Sort: String, CaseIterable, Codable, Sendable {
        case newest, oldest, name, rarity, species
    }

    /// Matches the pet's name, species or colouring, ignoring case and accents.
    public var text = ""
    /// Empty means any.
    public var species: Set<String> = []
    public var rarities: Set<Rarity> = []
    public var kinds: Set<ColouringKind> = []
    public var personalities: Set<Personality> = []
    public var favouritesOnly = false
    public var sort = Sort.newest
    /// Favourites first, whatever the sort.
    public var favouritesFirst = true

    public init() {}

    /// How many filters are switched on (not counting the search text or the sort).
    public var activeFilterCount: Int {
        [!species.isEmpty, !rarities.isEmpty, !kinds.isEmpty, !personalities.isEmpty, favouritesOnly]
            .count(where: \.self)
    }

    public mutating func clearFilters() {
        species = []
        rarities = []
        kinds = []
        personalities = []
        favouritesOnly = false
    }

    public func matches(_ pet: Pet, in catalog: Catalog) -> Bool {
        let kind = catalog.species(id: pet.speciesID)
        guard species.isEmpty || species.contains(pet.speciesID),
            rarities.isEmpty || kind.map({ rarities.contains($0.rarity) }) == true,
            kinds.isEmpty || kinds.contains(catalog.colouringKind(of: pet)),
            personalities.isEmpty || personalities.contains(pet.personality),
            !favouritesOnly || pet.isFavorite
        else { return false }
        let needle = text.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return true }
        let haystack = [pet.name, kind?.name ?? pet.speciesID, catalog.colouring(of: pet)?.name ?? ""]
        return haystack.contains { $0.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    /// The matching pets in order.
    public func apply(to pets: [Pet], in catalog: Catalog) -> [Pet] {
        pets.filter { matches($0, in: catalog) }.sorted { lhs, rhs in
            if favouritesFirst, lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
            return ordered(lhs, rhs, in: catalog)
        }
    }

    /// The matching pets, a section per species (in catalog order), each sorted.
    public func grouped(_ pets: [Pet], in catalog: Catalog) -> [RosterGroup] {
        let matching = apply(to: pets, in: catalog)
        return catalog.species.compactMap { species in
            let members = matching.filter { $0.speciesID == species.id }
            return members.isEmpty ? nil : RosterGroup(species: species, pets: members)
        }
    }

    private func ordered(_ lhs: Pet, _ rhs: Pet, in catalog: Catalog) -> Bool {
        let newestFirst = (lhs.hatchedAt, lhs.id.uuidString) > (rhs.hatchedAt, rhs.id.uuidString)
        switch sort {
        case .newest: return newestFirst
        case .oldest: return !newestFirst
        case .name:
            let order = lhs.name.localizedStandardCompare(rhs.name)
            return order == .orderedSame ? newestFirst : order == .orderedAscending
        case .rarity:
            let left = catalog.species(id: lhs.speciesID)?.rarity ?? .common
            let right = catalog.species(id: rhs.speciesID)?.rarity ?? .common
            return left == right ? newestFirst : left > right
        case .species:
            let left = catalog.species.firstIndex { $0.id == lhs.speciesID } ?? .max
            let right = catalog.species.firstIndex { $0.id == rhs.speciesID } ?? .max
            return left == right ? newestFirst : left < right
        }
    }
}

/// One species' pets in the roster.
public struct RosterGroup: Hashable, Sendable, Identifiable {
    public var species: Species
    public var pets: [Pet]
    public var id: String { species.id }
}

/// The roster at a glance.
public struct RosterStats: Hashable, Sendable {
    public var pets: Int
    public var speciesOwned: Int
    public var speciesTotal: Int
    public var shinies: Int
    public var specials: Int
    public var favourites: Int
    public var newest: Pet?

    public init(pets: [Pet], catalog: Catalog) {
        self.pets = pets.count
        speciesOwned = Set(pets.map(\.speciesID)).count
        speciesTotal = catalog.species.count
        shinies = pets.count(where: \.isShiny)
        specials = pets.count { catalog.colouringKind(of: $0) == .special }
        favourites = pets.count(where: \.isFavorite)
        newest = pets.max { $0.hatchedAt < $1.hatchedAt }
    }
}

/// Every colouring of one species side by side: which you own (and how many of each), and which
/// you're still missing. For comparing colourings on a pet's page.
public struct ColouringShelf: Hashable, Sendable {
    public struct Slot: Hashable, Sendable, Identifiable {
        public var colouring: ColorVariant
        public var isShiny: Bool
        /// Your pets in this colouring, oldest first.
        public var owned: [Pet]
        public var id: String { colouring.id }
    }

    public var species: Species
    public var slots: [Slot]

    public init(species: Species, pets: [Pet]) {
        self.species = species
        let mine = pets.filter { $0.speciesID == species.id }.sorted { $0.hatchedAt < $1.hatchedAt }
        let colourings = species.variants.map { ($0, false) } + (species.shiny.map { [($0, true)] } ?? [])
        slots = colourings.map { colouring, shiny in
            Slot(
                colouring: colouring, isShiny: shiny,
                owned: mine.filter { species.colorVariant(for: $0.variant)?.id == colouring.id && $0.isShiny == shiny })
        }
    }

    public var ownedCount: Int { slots.count { !$0.owned.isEmpty } }
}
