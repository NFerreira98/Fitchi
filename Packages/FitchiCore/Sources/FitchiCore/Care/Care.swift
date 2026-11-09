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
    public static func use(
        _ item: ShopItem,
        on pet: inout Pet,
        species: Species,
        inventory: inout Inventory,
        at date: Date,
        in context: DecayContext
    ) throws(CareError) {
        guard item.category.isConsumable else { throw .notConsumable }
        let condition = pet.condition(at: date, in: context)
        guard condition.acceptsCare else { throw .petRanAway }
        guard inventory.consume(item.id) else { throw .noneLeft }

        let multiplier = effectMultiplier(of: item, for: pet, species: species, condition: condition, config: context.config)
        for (stat, delta) in item.effects {
            let scaled = delta > 0 ? delta * multiplier : delta
            pet.setStat(stat, to: pet.value(of: stat, at: date, in: context) + scaled, at: date)
        }
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
