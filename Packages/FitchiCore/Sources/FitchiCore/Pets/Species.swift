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
    /// Stand-in art for species without drawings yet.
    public var emoji: String?
    /// Regular colourings, rolled by weight at hatch. Empty means the species' default art.
    public var variants: [ColorVariant]
    /// The rare shiny colouring (see `VariantRules.shinyChance`).
    public var shiny: ColorVariant?

    public init(
        id: String,
        name: String,
        rarity: Rarity,
        traitRanges: TraitRanges,
        favoriteItemIDs: [String] = [],
        defaultNames: [String] = [],
        emoji: String? = nil,
        variants: [ColorVariant] = [],
        shiny: ColorVariant? = nil
    ) {
        self.id = id
        self.name = name
        self.rarity = rarity
        self.traitRanges = traitRanges
        self.favoriteItemIDs = favoriteItemIDs
        self.defaultNames = defaultNames
        self.emoji = emoji
        self.variants = variants
        self.shiny = shiny
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, rarity, traitRanges, favoriteItemIDs, defaultNames, emoji, variants, shiny
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        rarity = try container.decode(Rarity.self, forKey: .rarity)
        traitRanges = try container.decode(TraitRanges.self, forKey: .traitRanges)
        favoriteItemIDs = try container.decodeIfPresent([String].self, forKey: .favoriteItemIDs) ?? []
        defaultNames = try container.decodeIfPresent([String].self, forKey: .defaultNames) ?? []
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji)
        variants = try container.decodeIfPresent([ColorVariant].self, forKey: .variants) ?? []
        shiny = try container.decodeIfPresent(ColorVariant.self, forKey: .shiny)
    }
}
