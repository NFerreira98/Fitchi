import Foundation

/// The four one-tap care buttons on the watch.
public enum CareAction: String, CaseIterable, Codable, Sendable {
    case feed
    case play
    case wash
    case rest

    public var category: ItemCategory {
        switch self {
        case .feed: .food
        case .play: .toy
        case .wash: .hygiene
        case .rest: .rest
        }
    }

    /// The stat this action is mainly for.
    public var stat: Stat {
        switch self {
        case .feed: .hunger
        case .play: .happiness
        case .wash: .cleanliness
        case .rest: .energy
        }
    }
}

public enum QuickCareError: Error, Equatable, Sendable {
    /// The main stat is already (nearly) full, so don't waste Pep.
    case alreadySatisfied(Stat)
    case cantAfford(price: Int)
    case noItem
    case care(CareError)
}

/// One-tap care: use a matching item from the inventory if there is one, otherwise buy one
/// and use it straight away.
public enum QuickCare {
    /// Above this the main stat counts as full.
    public static let satisfiedThreshold: Double = 95

    /// Which item a tap would use: an owned one first, then the species' favourite if
    /// affordable, then the cheapest.
    public static func item(
        for action: CareAction,
        species: Species,
        catalog: Catalog,
        inventory: Inventory,
        balance: Int
    ) -> ShopItem? {
        let candidates = catalog.items
            .filter { $0.category == action.category }
            .sorted { ($0.price, $0.id) < ($1.price, $1.id) }
        let isFavorite = { (item: ShopItem) in species.favoriteItemIDs.contains(item.id) }
        let owned = candidates.filter { inventory.count(of: $0.id) > 0 }
        if let item = owned.first(where: isFavorite) ?? owned.first { return item }
        return candidates.first { isFavorite($0) && $0.price <= balance } ?? candidates.first
    }

    public static func perform(
        _ action: CareAction,
        on pet: inout Pet,
        catalog: Catalog,
        wallet: inout Wallet,
        inventory: inout Inventory,
        at date: Date,
        in context: DecayContext
    ) throws(QuickCareError) -> CareOutcome {
        guard pet.value(of: action.stat, at: date, in: context) < satisfiedThreshold else {
            throw .alreadySatisfied(action.stat)
        }
        guard let species = catalog.species(id: pet.speciesID),
            let item = item(for: action, species: species, catalog: catalog, inventory: inventory, balance: wallet.balance)
        else { throw .noItem }

        // Work on copies so a failed step leaves nothing half-done.
        var newWallet = wallet
        var newInventory = inventory
        var newPet = pet
        if newInventory.count(of: item.id) == 0 {
            do {
                try Shop.buy(item, wallet: &newWallet, inventory: &newInventory, at: date)
            } catch {
                throw .cantAfford(price: item.price)
            }
        }
        let outcome: CareOutcome
        do {
            outcome = try Care.use(item, on: &newPet, species: species, inventory: &newInventory, at: date, in: context)
        } catch {
            throw .care(error)
        }
        wallet = newWallet
        inventory = newInventory
        pet = newPet
        return outcome
    }
}
