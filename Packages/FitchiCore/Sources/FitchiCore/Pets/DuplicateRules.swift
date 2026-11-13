import Foundation

/// How eggs go easy on repeats. The egg's rarity odds and the shiny chance never change; these
/// rules only steer *which* species and colouring hatch within the rarity that was rolled.
/// Bump the version when changing numbers.
public struct DuplicateRules: Hashable, Sendable {
    public var version: Int
    /// Weight multiplier for colourings the player hasn't found yet.
    public var newFindBoost: Double
    /// After this many repeats in a row, the next hatch is a new find, if the rolled rarity has
    /// anything left to find.
    public var pityAfter: Int
    /// Share of the egg's price paid back when a hatch is an exact repeat (species and colouring).
    public var refundShare: Double

    public init(version: Int, newFindBoost: Double, pityAfter: Int, refundShare: Double) {
        self.version = version
        self.newFindBoost = newFindBoost
        self.pityAfter = pityAfter
        self.refundShare = refundShare
    }

    public static let v1 = DuplicateRules(version: 1, newFindBoost: 4, pityAfter: 2, refundShare: 0.25)

    public func refund(for egg: EggType) -> Int {
        Int((Double(egg.price) * refundShare).rounded())
    }
}

/// What eggs need to know about the player's past hatches. Derived from the roster (pets never
/// leave it), so it syncs with the pets and is never stored.
public struct HatchHistory: Hashable, Sendable {
    /// Collection entry ids (`CollectionEntry.id`) the player has found.
    public var found: Set<String>
    /// Hatches in a row, most recent last, that added nothing to the collection.
    public var repeatsInARow: Int

    public init(found: Set<String> = [], repeatsInARow: Int = 0) {
        self.found = found
        self.repeatsInARow = repeatsInARow
    }

    public static let empty = HatchHistory()

    /// Replays the roster in hatch order.
    public init(pets: [Pet], catalog: Catalog) {
        var history = HatchHistory()
        for pet in pets.sorted(by: { $0.hatchedAt < $1.hatchedAt }) {
            guard let species = catalog.species(id: pet.speciesID) else { continue }
            history.record(species.collectionID(for: pet.variant))
        }
        self = history
    }

    /// Notes one hatch; returns whether it was a new find.
    @discardableResult
    public mutating func record(_ entryID: String) -> Bool {
        let isNew = found.insert(entryID).inserted
        repeatsInARow = isNew ? 0 : repeatsInARow + 1
        return isNew
    }
}

/// A hatched egg: the pet, whether it filled a new collection entry and any repeat refund.
public struct HatchResult: Hashable, Sendable {
    public var pet: Pet
    public var isNewFind: Bool
    /// Pep paid back for an exact repeat; 0 for new finds.
    public var refund: Int

    public init(pet: Pet, isNewFind: Bool, refund: Int) {
        self.pet = pet
        self.isNewFind = isNewFind
        self.refund = refund
    }
}

public extension Species {
    /// The collection entry a pet of this species with `variant` fills (`CollectionEntry.id`).
    func collectionID(for variant: PetVariant?) -> String {
        "\(id)/\(colorVariant(for: variant)?.id ?? "-")"
    }
}
