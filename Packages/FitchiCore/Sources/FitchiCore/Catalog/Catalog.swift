import Foundation

/// All game content: species, shop items, eggs and achievements.
///
/// Content is data, not code. It lives as JSON in the repo's `Content/` folder and is bundled
/// into the apps. Adding a hat means a JSON entry plus art, never new Swift.
public struct Catalog: Codable, Hashable, Sendable {
    public var species: [Species]
    public var items: [ShopItem]
    public var eggs: [EggType]
    public var achievements: [Achievement]

    /// The art style every player owns for free.
    public static let defaultArtStyleID = "classic"

    public init(species: [Species], items: [ShopItem], eggs: [EggType], achievements: [Achievement]) {
        self.species = species
        self.items = items
        self.eggs = eggs
        self.achievements = achievements
    }

    public enum File: String, CaseIterable, Sendable {
        case species = "species.json"
        case items = "items.json"
        case eggs = "eggs.json"
        case achievements = "achievements.json"
    }

    /// Loads the catalog from a directory containing the four JSON files.
    public static func load(from directory: URL) throws -> Catalog {
        func data(_ file: File) throws -> Data {
            try Data(contentsOf: directory.appendingPathComponent(file.rawValue))
        }
        let decoder = JSONDecoder()
        return Catalog(
            species: try decoder.decode([Species].self, from: data(.species)),
            items: try decoder.decode([ShopItem].self, from: data(.items)),
            eggs: try decoder.decode([EggType].self, from: data(.eggs)),
            achievements: try decoder.decode([Achievement].self, from: data(.achievements))
        )
    }

    public func species(id: String) -> Species? { species.first { $0.id == id } }
    public func item(id: String) -> ShopItem? { items.first { $0.id == id } }
    public func egg(id: String) -> EggType? { eggs.first { $0.id == id } }

    /// Content problems that would break the game. Empty means the catalog is valid.
    /// Run in tests so a bad JSON edit fails CI instead of crashing the app.
    public func validate() -> [String] {
        duplicateIDProblems() + speciesProblems() + itemProblems() + eggProblems()
    }

    private func duplicateIDProblems() -> [String] {
        let groups: [(String, [String])] = [
            ("species", species.map(\.id)), ("item", items.map(\.id)),
            ("egg", eggs.map(\.id)), ("achievement", achievements.map(\.id)),
        ]
        return groups.flatMap { kind, ids in
            Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
                .map { "Duplicate \(kind) id '\($0)'" }
        }
    }

    private func speciesProblems() -> [String] {
        var problems: [String] = []
        if !species.contains(where: { $0.rarity == .common }) {
            problems.append("No common species: the starter egg cannot hatch")
        }
        let itemIDs = Set(items.map(\.id))
        for spec in species {
            if spec.traitRanges.all.contains(where: { $0.lowerBound < 0 || $0.upperBound > 1 }) {
                problems.append("Species '\(spec.id)' has trait ranges outside 0...1")
            }
            problems += spec.favoriteItemIDs.filter { !itemIDs.contains($0) }
                .map { "Species '\(spec.id)' favorite '\($0)' is not an item" }
        }
        return problems
    }

    private func itemProblems() -> [String] {
        items.flatMap { item -> [String] in
            var problems: [String] = []
            if item.price <= 0 { problems.append("Item '\(item.id)' must have a positive price") }
            if item.category.isConsumable && item.effects.isEmpty {
                problems.append("Consumable '\(item.id)' has no effects")
            }
            if item.category == .accessory && item.slot == nil {
                problems.append("Accessory '\(item.id)' has no slot")
            }
            return problems
        }
    }

    private func eggProblems() -> [String] {
        eggs.flatMap { egg -> [String] in
            var problems: [String] = []
            if egg.price <= 0 { problems.append("Egg '\(egg.id)' must have a positive price") }
            let reachable = egg.odds.contains { odds in odds.value > 0 && species.contains { $0.rarity == odds.key } }
            if !reachable { problems.append("Egg '\(egg.id)' cannot hatch any species") }
            return problems
        }
    }
}
