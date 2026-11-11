import Foundation

public enum CareError: Error, Equatable {
    case petRanAway
    case notConsumable
    case noneLeft
    case notAnAccessory
    case notOwned
}

/// Using items on pets.
public enum Care {
    /// Gives one consumable to a pet: consumes it from the inventory and applies its effects.
    ///
    /// Positive effects are scaled by the pet's personality, whether the item is a species
    /// favorite, and halved while the pet is sick.
    @discardableResult
    public static func use(
        _ item: ShopItem,
        on pet: inout Pet,
        species: Species,
        inventory: inout Inventory,
        at date: Date,
        in context: DecayContext
    ) throws(CareError) -> CareOutcome {
        guard item.category.isConsumable else { throw .notConsumable }
        let condition = pet.condition(at: date, in: context)
        guard condition.acceptsCare else { throw .petRanAway }
        guard inventory.consume(item.id) else { throw .noneLeft }

        let multiplier = effectMultiplier(
            of: item, for: pet, species: species, condition: condition, config: context.config)
        var changes: [Stat: Double] = [:]
        for (stat, delta) in item.effects {
            let scaled = delta > 0 ? delta * multiplier : delta
            let before = pet.value(of: stat, at: date, in: context)
            pet.setStat(stat, to: before + scaled, at: date)
            changes[stat] = pet.value(of: stat, at: date, in: context) - before
        }
        let reaction: CareOutcome.Reaction
        if condition == .sick || condition == .packing {
            reaction = .unwell
        } else if species.favoriteItemIDs.contains(item.id) {
            reaction = .loved
        } else {
            reaction = multiplier < 1 ? .meh : .enjoyed
        }
        return CareOutcome(itemID: item.id, changes: changes, reaction: reaction)
    }

    public static func effectMultiplier(
        of item: ShopItem,
        for pet: Pet,
        species: Species,
        condition: PetCondition,
        config: DecayConfig
    ) -> Double {
        let isFavorite = species.favoriteItemIDs.contains(item.id)
        let sickness = condition == .sick || condition == .packing ? config.sickCareMultiplier : 1
        return pet.personality.careMultiplier(for: item.category, isFavorite: isFavorite) * sickness
    }
}

/// What happened when a pet was given an item, for the UI to react to.
public struct CareOutcome: Hashable, Sendable {
    public enum Reaction: String, Hashable, Sendable {
        /// A species favourite.
        case loved
        case enjoyed
        /// The personality didn't care for it (e.g. a picky eater given the wrong food).
        case meh
        /// Sick pets get less out of care until they recover.
        case unwell
    }

    public var itemID: String
    /// Actual change per stat after clamping to 0...100.
    public var changes: [Stat: Double]
    public var reaction: Reaction
}

/// Dressing pets up.
public enum Wardrobe {
    public static func equip(_ item: ShopItem, on pet: inout Pet, inventory: Inventory) throws(CareError) {
        guard item.category == .accessory, let slot = item.slot else { throw .notAnAccessory }
        guard inventory.owns(item.id) else { throw .notOwned }
        pet.equipped[slot] = item.id
    }

    public static func unequip(_ slot: AccessorySlot, on pet: inout Pet) {
        pet.equipped[slot] = nil
    }
}
