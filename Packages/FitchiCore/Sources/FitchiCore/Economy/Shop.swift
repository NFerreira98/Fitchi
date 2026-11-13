import Foundation

public enum ShopError: Error, Equatable {
    case insufficientFunds(price: Int, balance: Int)
    case alreadyOwned
}

/// Buying things with Pep.
public enum Shop {
    /// Buys an item: records the spend in the wallet and adds the item to the inventory.
    public static func buy(
        _ item: ShopItem,
        wallet: inout Wallet,
        inventory: inout Inventory,
        at date: Date
    ) throws(ShopError) {
        if !item.category.isConsumable && inventory.owns(item.id) { throw .alreadyOwned }
        guard wallet.canAfford(item.price) else {
            throw .insufficientFunds(price: item.price, balance: wallet.balance)
        }
        wallet.record(.purchase(itemID: item.id, price: item.price, at: date))
        inventory.add(item)
    }

    /// Buys and hatches an egg. The new pet is returned; add it to the roster.
    /// Buys and hatches an egg. An exact repeat of something already in the collection pays back
    /// part of the price (`DuplicateRules.refundShare`).
    public static func buyEgg(
        _ egg: EggType,
        from catalog: Catalog,
        wallet: inout Wallet,
        at date: Date,
        history: HatchHistory = .empty,
        duplicates: DuplicateRules = .v1,
        using rng: inout some RandomNumberGenerator
    ) throws -> HatchResult {
        guard wallet.canAfford(egg.price) else {
            throw ShopError.insufficientFunds(price: egg.price, balance: wallet.balance)
        }
        let pet = try Hatchery.hatch(
            egg, from: catalog, at: date, history: history, duplicates: duplicates, using: &rng)
        wallet.record(.purchase(itemID: egg.id, price: egg.price, at: date))
        let entryID = catalog.species(id: pet.speciesID)?.collectionID(for: pet.variant)
        let isNewFind = entryID.map { !history.found.contains($0) } ?? true
        let refund = isNewFind ? 0 : duplicates.refund(for: egg)
        if refund > 0 {
            wallet.record(.repeatRefund(petID: pet.id, eggID: egg.id, amount: refund, at: date))
        }
        return HatchResult(pet: pet, isNewFind: isNewFind, refund: refund)
    }
}
