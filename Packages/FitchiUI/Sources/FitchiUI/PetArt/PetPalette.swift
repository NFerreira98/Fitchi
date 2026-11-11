import FitchiCore
import Foundation

/// The colours one pet is painted with. Every species uses the same slots:
/// - `body`: main fur/skin.
/// - `belly`: muzzle, chest, paws, belly.
/// - `accent`: gills, ears, inner ears, tail tip.
/// - `marking`: optional stripes, spots or patches, drawn in the style `pattern` names.
/// - `cheek`: blush and nose.
/// - `bow`: optional ribbon (a shiny flourish).
public struct PetPalette: Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let body: PetColor
    public let belly: PetColor
    public let accent: PetColor
    public let marking: PetColor?
    public let pattern: Pattern
    public let cheek: PetColor
    public let eye: PetColor
    public let bow: PetColor?
    public let isShiny: Bool

    public init(
        id: String, name: String, body: UInt32, belly: UInt32, accent: UInt32,
        marking: UInt32? = nil, pattern: Pattern = .none, cheek: UInt32 = 0xFF8FA8, bow: UInt32? = nil,
        isShiny: Bool = false
    ) {
        self.id = id
        self.name = name
        self.body = PetColor(hex: body)
        self.belly = PetColor(hex: belly)
        self.accent = PetColor(hex: accent)
        self.marking = marking.map(PetColor.init(hex:))
        self.pattern = marking == nil ? .none : pattern
        self.cheek = PetColor(hex: cheek)
        eye = PetColor(hex: 0x2A1A33)
        self.bow = bow.map(PetColor.init(hex:))
        self.isShiny = isShiny
    }

    public enum Pattern: String, Hashable, Sendable {
        case none, stripes, spots, patches
    }
}

public extension PetPalette {
    /// Builds a palette from catalog data. Unknown or malformed colours fall back to neutral tones.
    init(_ variant: ColorVariant, isShiny: Bool = false) {
        func hex(_ slot: String) -> UInt32? {
            guard let value = variant.colors[slot], value.hasPrefix("#") else { return nil }
            return UInt32(value.dropFirst(), radix: 16)
        }
        self.init(
            id: variant.id,
            name: variant.name,
            body: hex("body") ?? 0xD8D2CC,
            belly: hex("belly") ?? 0xFFFFFF,
            accent: hex("accent") ?? 0xFFB0C0,
            marking: hex("marking"),
            pattern: variant.pattern.flatMap(Pattern.init(rawValue:)) ?? .none,
            cheek: hex("cheek") ?? 0xFF8FA8,
            bow: hex("bow"),
            isShiny: isShiny
        )
    }

    /// The palette a pet of `species` with `variant` is drawn in.
    init(species: Species, variant: PetVariant?) {
        if let colouring = species.colorVariant(for: variant) {
            self.init(colouring, isShiny: variant?.isShiny == true && colouring.id == species.shiny?.id)
        } else {
            self.init(id: "default", name: species.name, body: 0xD8D2CC, belly: 0xFFFFFF, accent: 0xFFB0C0)
        }
    }

    /// Every colouring of a species, regular variants first and the shiny last.
    static func all(for species: Species) -> [PetPalette] {
        species.variants.map { PetPalette($0) } + (species.shiny.map { [PetPalette($0, isShiny: true)] } ?? [])
    }
}
