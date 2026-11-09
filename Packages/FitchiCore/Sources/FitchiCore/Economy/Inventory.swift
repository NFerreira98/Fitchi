/// What the player owns: stacks of consumables plus permanent cosmetics and art styles.
public struct Inventory: Codable, Hashable, Sendable {
    public private(set) var consumables: [String: Int]
    public private(set) var ownedItemIDs: Set<String>
    public var activeArtStyleID: String

    public init(
        consumables: [String: Int] = [:],
        ownedItemIDs: Set<String> = [],
        activeArtStyleID: String = Catalog.defaultArtStyleID
    ) {
        self.consumables = consumables
        self.ownedItemIDs = ownedItemIDs
        self.activeArtStyleID = activeArtStyleID
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
