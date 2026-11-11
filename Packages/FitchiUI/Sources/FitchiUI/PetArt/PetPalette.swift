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

// Look-check palettes. These move into Content/species.json once variant rolls exist in FitchiCore.
public extension PetPalette {
    static let axolotl: [PetPalette] = [
        PetPalette(id: "leucistic", name: "Blush", body: 0xFFC2D4, belly: 0xFFE4EC, accent: 0xE8508A),
        PetPalette(
            id: "wild", name: "Wild", body: 0x8C8A5A, belly: 0xB9B585, accent: 0x6E5A3A, marking: 0x5C5A36,
            pattern: .spots),
        PetPalette(id: "golden", name: "Golden", body: 0xFFD66B, belly: 0xFFF0B8, accent: 0xFF9A4D),
        PetPalette(
            id: "melanoid", name: "Midnight", body: 0x4A4E6B, belly: 0x6E7392, accent: 0x7C5CA8, cheek: 0xB07CC8),
        PetPalette(
            id: "shiny", name: "Shiny Amethyst", body: 0xB58AF0, belly: 0xE2CCFF, accent: 0xFF9A3C,
            marking: 0x8D62D6, pattern: .spots, cheek: 0xFF9A3C, isShiny: true
        ),
    ]

    static let cat: [PetPalette] = [
        PetPalette(
            id: "grey-tabby", name: "Grey Tabby", body: 0xA9B4C8, belly: 0xF4F1EE, accent: 0xFFB0C0, marking: 0x7C879E,
            pattern: .stripes),
        PetPalette(
            id: "ginger", name: "Ginger", body: 0xFFAA5C, belly: 0xFFF1DE, accent: 0xFFB0B8, marking: 0xE07F35,
            pattern: .stripes),
        PetPalette(id: "tuxedo", name: "Tuxedo", body: 0x3B3A48, belly: 0xF7F5F2, accent: 0xFF9DB2),
        PetPalette(
            id: "calico", name: "Calico", body: 0xF7F1EA, belly: 0xFFFFFF, accent: 0xFFB0C0, marking: 0xE89A52,
            pattern: .patches),
        PetPalette(
            id: "shiny", name: "Shiny Sugar", body: 0xFFFFFF, belly: 0xFFF3F7, accent: 0xFF8FB8,
            cheek: 0xFF8FB8, bow: 0xF2436E, isShiny: true
        ),
    ]

    static let dog: [PetPalette] = [
        PetPalette(id: "tan", name: "Honey", body: 0xE9B577, belly: 0xFFF1DC, accent: 0x9B6236),
        PetPalette(id: "chocolate", name: "Cocoa", body: 0x8A5A3C, belly: 0xD9B08C, accent: 0x5E3A26),
        PetPalette(
            id: "spotty", name: "Patch", body: 0xF6F1EA, belly: 0xFFFFFF, accent: 0x5A4436, marking: 0x5A4436,
            pattern: .patches),
        PetPalette(id: "husky", name: "Frost", body: 0x8E98AA, belly: 0xF5F5F7, accent: 0x5D6678),
        PetPalette(
            id: "shiny", name: "Shiny Starlight", body: 0x6A7FE0, belly: 0xD6E4FF, accent: 0xFFC94D,
            cheek: 0xFF9ACD, isShiny: true
        ),
    ]

    static func all(for speciesID: String) -> [PetPalette] {
        switch speciesID {
        case "axolotl": axolotl
        case "cat": cat
        default: dog
        }
    }
}
