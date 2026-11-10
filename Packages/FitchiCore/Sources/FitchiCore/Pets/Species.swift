/// A kind of pet (dog, cat, axolotl, ...). Loaded from `Content/species.json`.
public struct Species: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var rarity: Rarity
    public var traitRanges: TraitRanges
    /// Items this species loves; they restore more.
    public var favoriteItemIDs: [String]
    /// Suggested names offered at hatch time.
    public var defaultNames: [String]
    /// Stand-in art until sprites exist.
    public var emoji: String?

    public init(
        id: String,
        name: String,
        rarity: Rarity,
        traitRanges: TraitRanges,
        favoriteItemIDs: [String] = [],
        defaultNames: [String] = [],
        emoji: String? = nil
    ) {
        self.id = id
        self.name = name
        self.rarity = rarity
        self.traitRanges = traitRanges
        self.favoriteItemIDs = favoriteItemIDs
        self.defaultNames = defaultNames
        self.emoji = emoji
    }
}
