import Foundation

/// One colouring of a species (e.g. a ginger cat). Loaded from `Content/species.json`.
///
/// Core only rolls and stores variants; the colours are opaque `#RRGGBB` strings that the
/// renderer interprets. Slots: `body`, `belly`, `accent`, optional `marking` (+ `pattern`),
/// `cheek`, optional `bow`.
public struct ColorVariant: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    /// Relative odds among the species' regular variants.
    public var weight: Double
    public var colors: [String: String]
    /// How `marking` is drawn: `stripes`, `spots` or `patches`.
    public var pattern: String?
    /// A special colouring that only hatches in these conditions (snow, night, autumn…); nil
    /// for a regular one.
    public var when: HatchCondition?

    public init(
        id: String, name: String, weight: Double = 1, colors: [String: String], pattern: String? = nil,
        when: HatchCondition? = nil
    ) {
        self.when = when
        self.id = id
        self.name = name
        self.weight = weight
        self.colors = colors
        self.pattern = pattern
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, weight, colors, pattern, when
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        weight = try container.decodeIfPresent(Double.self, forKey: .weight) ?? 1
        colors = try container.decode([String: String].self, forKey: .colors)
        pattern = try container.decodeIfPresent(String.self, forKey: .pattern)
        when = try container.decodeIfPresent(HatchCondition.self, forKey: .when)
    }

    public static let requiredColorSlots = ["body", "belly", "accent"]
    public static let knownColorSlots: Set<String> = ["body", "belly", "accent", "marking", "cheek", "bow"]
    public static let knownPatterns: Set<String> = ["stripes", "spots", "patches"]

    /// Problems with this variant's data, for `Catalog.validate()`.
    func problems(in speciesID: String) -> [String] {
        var problems: [String] = []
        let label = "Species '\(speciesID)' variant '\(id)'"
        if weight <= 0 { problems.append("\(label) must have a positive weight") }
        for slot in Self.requiredColorSlots where colors[slot] == nil {
            problems.append("\(label) is missing colour '\(slot)'")
        }
        for (slot, value) in colors.sorted(by: { $0.key < $1.key }) {
            if !Self.knownColorSlots.contains(slot) { problems.append("\(label) has unknown colour slot '\(slot)'") }
            if !Self.isHexColor(value) { problems.append("\(label) colour '\(slot)' is not #RRGGBB") }
        }
        if let when, when.isEmpty { problems.append("\(label) has an empty 'when' condition") }
        if let pattern, !Self.knownPatterns.contains(pattern) {
            problems.append("\(label) has unknown pattern '\(pattern)'")
        }
        return problems
    }

    static func isHexColor(_ value: String) -> Bool {
        value.count == 7 && value.first == "#" && value.dropFirst().allSatisfy(\.isHexDigit)
    }
}

/// Which colouring an individual pet hatched with.
public struct PetVariant: Codable, Hashable, Sendable {
    public var id: String
    public var isShiny: Bool

    public init(id: String, isShiny: Bool = false) {
        self.id = id
        self.isShiny = isShiny
    }
}

/// Odds for colour variants. Bump the version when changing odds so old pets keep theirs.
public struct VariantRules: Hashable, Sendable {
    public var version: Int
    /// Chance that any hatch is shiny (when the species has a shiny).
    public var shinyChance: Double

    public static let v1 = VariantRules(version: 1, shinyChance: 1.0 / 64)

    /// Rolls a variant: shiny first, otherwise a weighted pick among regular variants.
    /// Returns nil for species without variants (they use their default art).
    public func roll(for species: Species, using rng: inout some RandomNumberGenerator) -> PetVariant? {
        let shinyRoll = Double.random(in: 0..<1, using: &rng)
        if let shiny = species.shiny, shinyRoll < shinyChance {
            return PetVariant(id: shiny.id, isShiny: true)
        }
        let regular = species.regularVariants
        let weights = Dictionary(regular.map { ($0.id, $0.weight) }, uniquingKeysWith: +)
        guard let id = rng.weightedPick(weights, order: regular.map(\.id)) else { return nil }
        return PetVariant(id: id)
    }

    /// Like `roll(for:using:)`, but special colourings whose condition holds at `moment` can turn up too.
    public func roll(for species: Species, at moment: HatchMoment, using rng: inout some RandomNumberGenerator)
        -> PetVariant?
    {
        let shinyRoll = Double.random(in: 0..<1, using: &rng)
        if let shiny = species.shiny, shinyRoll < shinyChance {
            return PetVariant(id: shiny.id, isShiny: true)
        }
        let open = species.variants(at: moment)
        let weights = Dictionary(open.map { ($0.id, $0.weight) }, uniquingKeysWith: +)
        guard let id = rng.weightedPick(weights, order: open.map(\.id)) else { return nil }
        return PetVariant(id: id)
    }
}

public extension Species {
    /// The colouring for a pet's variant; pets from before variants existed get the first one.
    func colorVariant(for variant: PetVariant?) -> ColorVariant? {
        if let variant {
            if variant.isShiny, let shiny, shiny.id == variant.id { return shiny }
            if let match = variants.first(where: { $0.id == variant.id }) { return match }
        }
        return variants.first
    }
}
