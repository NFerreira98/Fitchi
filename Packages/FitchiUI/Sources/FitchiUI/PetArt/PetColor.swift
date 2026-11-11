import SwiftUI

/// An sRGB colour used by pet palettes. Shading and outline tones are derived from one base colour
/// so a palette only needs a handful of entries.
public struct PetColor: Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// `0xRRGGBB`.
    public init(hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    public func mixed(with other: PetColor, amount: Double) -> PetColor {
        PetColor(
            red: red + (other.red - red) * amount,
            green: green + (other.green - green) * amount,
            blue: blue + (other.blue - blue) * amount
        )
    }

    public var color: Color { Color(red: red, green: green, blue: blue) }

    static let white = PetColor(red: 1, green: 1, blue: 1)
    /// Shadows lean cool and purple, which reads softer than plain darkening.
    static let shadowInk = PetColor(red: 0.32, green: 0.20, blue: 0.45)
    static let lineInk = PetColor(red: 0.17, green: 0.09, blue: 0.20)
}

/// The four tones a body part is painted with.
struct Tone {
    let base: Color
    let shade: Color
    let light: Color
    let line: Color

    init(_ color: PetColor) {
        base = color.color
        shade = color.mixed(with: .shadowInk, amount: 0.3).color
        light = color.mixed(with: .white, amount: 0.5).color
        line = color.mixed(with: .lineInk, amount: 0.7).color
    }
}
