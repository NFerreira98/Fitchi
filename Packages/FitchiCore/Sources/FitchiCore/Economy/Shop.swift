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
    public static func buyEgg(
        _ egg: EggType,
        from catalog: Catalog,
        wallet: inout Wallet,
        at date: Date,
        using rng: inout some RandomNumberGenerator
    ) throws -> Pet {
        guard wallet.canAfford(egg.price) else {
            throw ShopError.insufficientFunds(price: egg.price, balance: wallet.balance)
        }
        let pet = try Hatchery.hatch(egg, from: catalog, at: date, using: &rng)
        wallet.record(.purchase(itemID: egg.id, price: egg.price, at: date))
        return pet
    }
}
