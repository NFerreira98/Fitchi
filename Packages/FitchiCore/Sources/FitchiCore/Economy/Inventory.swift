/// What the player owns: stacks of consumables plus permanent cosmetics and art styles.
public struct Inventory: Codable, Hashable, Sendable {
    public private(set) var consumables: [String: Int]
    public private(set) var ownedItemIDs: Set<String>
    public var activeArtStyleID: String
    /// The scene shown behind every pet; the default meadow is always owned.
    public private(set) var activeBackdropID: String

    public init(
        consumables: [String: Int] = [:],
        ownedItemIDs: Set<String> = [],
        activeArtStyleID: String = Catalog.defaultArtStyleID,
        activeBackdropID: String = Catalog.defaultBackdropID
    ) {
        self.consumables = consumables
        self.ownedItemIDs = ownedItemIDs
        self.activeArtStyleID = activeArtStyleID
        self.activeBackdropID = activeBackdropID
    }

    private enum CodingKeys: String, CodingKey {
        case consumables, ownedItemIDs, activeArtStyleID, activeBackdropID
    }

    /// Tolerates inventories saved before backdrops existed.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        consumables = try container.decodeIfPresent([String: Int].self, forKey: .consumables) ?? [:]
        ownedItemIDs = try container.decodeIfPresent(Set<String>.self, forKey: .ownedItemIDs) ?? []
        activeArtStyleID =
            try container.decodeIfPresent(String.self, forKey: .activeArtStyleID) ?? Catalog.defaultArtStyleID
        activeBackdropID =
            try container.decodeIfPresent(String.self, forKey: .activeBackdropID) ?? Catalog.defaultBackdropID
    }

    /// Switches backdrop. Only owned backdrops (or the free default) can be chosen.
    public mutating func selectBackdrop(_ id: String) -> Bool {
        guard id == Catalog.defaultBackdropID || ownedItemIDs.contains(id) else { return false }
        activeBackdropID = id
        return true
    }

    /// Adds permanent items owned elsewhere (another device, or purchases in the ledger).
    /// Ownership only ever grows, so merging copies never loses something that was paid for.
    public mutating func grantOwnership(of itemIDs: some Sequence<String>) {
        ownedItemIDs.formUnion(itemIDs)
    }

    public func count(of itemID: String) -> Int { consumables[itemID, default: 0] }

    public func owns(_ itemID: String) -> Bool {
        ownedItemIDs.contains(itemID) || count(of: itemID) > 0
    }

    mutating func add(_ item: ShopItem) {
        if item.category.isConsumable {
            consumables[item.id, default: 0] += 1
        } else {
            ownedItemIDs.insert(item.id)
        }
    }

    /// Removes one consumable. Returns false if none were left.
    mutating func consume(_ itemID: String) -> Bool {
        guard count(of: itemID) > 0 else { return false }
        consumables[itemID, default: 0] -= 1
        if consumables[itemID] == 0 { consumables[itemID] = nil }
        return true
    }
}
