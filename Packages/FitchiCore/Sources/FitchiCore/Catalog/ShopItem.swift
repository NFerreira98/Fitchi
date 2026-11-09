/// What kind of thing a shop item is.
public enum ItemCategory: String, Codable, CaseIterable, Sendable {
    case food
    case treat
    case toy
    case hygiene
    case rest
    case accessory
    case artStyle

    /// Consumables are used up when given to a pet; everything else is owned permanently.
    public var isConsumable: Bool {
        switch self {
        case .food, .treat, .toy, .hygiene, .rest: true
        case .accessory, .artStyle: false
        }
    }
}

/// Something purchasable with Pep. Loaded from `Content/items.json`.
public struct ShopItem: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var description: String
    public var category: ItemCategory
    public var price: Int
    /// Stat changes when used on a pet (consumables only). Negative values are allowed,
    /// e.g. playing with a toy costs a little energy.
    public var effects: [Stat: Double]
    /// Where an accessory is worn (accessories only).
    public var slot: AccessorySlot?

    public init(
        id: String,
        name: String,
        description: String = "",
        category: ItemCategory,
        price: Int,
        effects: [Stat: Double] = [:],
        slot: AccessorySlot? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.price = price
        self.effects = effects
        self.slot = slot
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, category, price, effects, slot
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        category = try container.decode(ItemCategory.self, forKey: .category)
        price = try container.decode(Int.self, forKey: .price)
        effects = try container.decodeIfPresent([Stat: Double].self, forKey: .effects) ?? [:]
        slot = try container.decodeIfPresent(AccessorySlot.self, forKey: .slot)
    }
}

/// An egg that hatches a random pet. Odds are data so the app can always show them to players.
/// Loaded from `Content/eggs.json`.
public struct EggType: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var price: Int
    /// Relative weight per rarity (need not sum to 100).
    public var odds: [Rarity: Double]

    public init(id: String, name: String, price: Int, odds: [Rarity: Double]) {
        self.id = id
        self.name = name
        self.price = price
        self.odds = odds
    }

    /// Odds normalised to percentages, for display.
    public var displayOdds: [Rarity: Double] {
        let total = odds.values.reduce(0, +)
        guard total > 0 else { return [:] }
        return odds.mapValues { $0 / total * 100 }
    }
}
