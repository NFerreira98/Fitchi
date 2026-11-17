import SwiftUI

/// The colours a screen takes from the pet's world, so the page around the scene belongs to it:
/// pale sky and soft ground by day, warm at sunrise and sunset, deep blue after dark. Computed
/// from the backdrop and the scene light, the same way the scene is.
public struct WorldTint: Hashable, Sendable {
    /// Page colour at the top and at the bottom.
    public let top: Color
    public let bottom: Color
    /// Night: the page is dark and wants light text.
    public let isDark: Bool

    public init(backdrop: SceneBackdrop.Kind, light: SceneLight) {
        let tones = backdrop.pageTones
        // Washed well towards white, so it stays a page and not a second scene.
        let sky = tones.sky.mixed(with: .white, amount: 0.42)
        let ground = tones.ground.mixed(with: .white, amount: 0.58)
        // The starry night is always night, lit the same whatever the clock says.
        let light = backdrop == .starryNight ? .day : light
        let litSky = Lighting.lit(sky, light: light, indoor: backdrop.isIndoor)
        top = litSky.color
        bottom = Lighting.lit(ground, light: light, indoor: backdrop.isIndoor).color
        isDark = litSky.luminance < 0.45
    }

    /// Midday in the meadow.
    public static let day = WorldTint(backdrop: .meadow, light: .day)

    /// The page background.
    public var page: LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }

    /// A translucent card that sits on the page.
    public var card: Color { isDark ? .white.opacity(0.1) : .white.opacity(0.62) }
    /// A hairline along a card's edge, like the highlight on the pet art.
    public var cardEdge: Color { isDark ? .white.opacity(0.1) : .white.opacity(0.9) }
    /// A tile inside a card (a care button).
    public var tile: Color { isDark ? .white.opacity(0.08) : .black.opacity(0.05) }
}

extension EnvironmentValues {
    @Entry public var worldTint = WorldTint.day
}

/// A card on a tinted page: translucent white with a soft edge and shadow.
private struct WorldCard: ViewModifier {
    @Environment(\.worldTint) private var tint
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(tint.card, in: .rect(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(tint.cardEdge, lineWidth: 1))
            .shadow(color: .black.opacity(tint.isDark ? 0.3 : 0.07), radius: 10, y: 4)
    }
}

/// A whole screen on the tinted page: the system's grey list or scroll background gives way to
/// the world's colours.
private struct WorldPage: ViewModifier {
    @Environment(\.worldTint) private var tint

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background { tint.page.ignoresSafeArea() }
    }
}

/// List rows as translucent cards on the tinted page.
private struct WorldRow: ViewModifier {
    @Environment(\.worldTint) private var tint

    func body(content: Content) -> some View {
        content.listRowBackground(tint.card)
    }
}

extension View {
    /// Draws this view on a `WorldCard` for the current `worldTint`.
    public func worldCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(WorldCard(cornerRadius: cornerRadius))
    }

    /// Puts a screen (a `List` or `ScrollView`) on the world's tinted page.
    public func worldPage() -> some View {
        modifier(WorldPage())
    }

    /// Gives a `List` section's rows the translucent card background. Apply to each `Section`.
    public func worldRow() -> some View {
        modifier(WorldRow())
    }
}

extension SceneBackdrop.Kind {
    /// The sky near the horizon (or the wall) and the ground (or floor), for tinting a page.
    var pageTones: (sky: PetColor, ground: PetColor) {
        switch self {
        case .meadow: (PetColor(hex: 0xDBF2FF), PetColor(hex: 0x8CCC80))
        case .pond: (PetColor(hex: 0xFFEDD6), PetColor(hex: 0x8FCC85))
        case .snowyHill: (PetColor(hex: 0xE8EEFB), PetColor(hex: 0xDCE7F7))
        case .beach: (PetColor(hex: 0xD9F3FF), PetColor(hex: 0xF0D9A8))
        case .starryNight: (PetColor(hex: 0x2B3466), PetColor(hex: 0x2F4D3C))
        case .forest: (PetColor(hex: 0xE4F5E8), PetColor(hex: 0x7BC173))
        case .garden: (PetColor(hex: 0xE2F4FF), PetColor(hex: 0x8FD27A))
        case .bedroom: (PetColor(hex: 0xE6DCF7), PetColor(hex: 0xE8C9A0))
        case .livingRoom: (PetColor(hex: 0xFFE3CC), PetColor(hex: 0xD9A877))
        case .kitchen: (PetColor(hex: 0xDDF0EC), PetColor(hex: 0xF3D6D6))
        case .playroom: (PetColor(hex: 0xD6F1EA), PetColor(hex: 0xEBCB9F))
        }
    }
}

extension Lighting {
    /// `apply`, for one colour: the same multiply tints a scene gets at dawn, dusk and night.
    static func lit(_ color: PetColor, light: SceneLight, indoor: Bool) -> PetColor {
        var lit = color
        if light.warmth > 0.01 {
            lit = lit.multiplied(
                by: PetColor(red: 1, green: 0.8, blue: 0.66), amount: (indoor ? 0.3 : 0.5) * light.warmth)
        }
        if light.night > 0.01 {
            let shade =
                indoor ? PetColor(red: 0.42, green: 0.38, blue: 0.55) : PetColor(red: 0.2, green: 0.25, blue: 0.5)
            lit = lit.multiplied(by: shade, amount: (indoor ? 0.6 : 0.78) * light.night)
        }
        return lit
    }
}

extension PetColor {
    /// A multiply blend with `other` at `amount` opacity.
    func multiplied(by other: PetColor, amount: Double) -> PetColor {
        PetColor(
            red: red * (1 - amount + amount * other.red),
            green: green * (1 - amount + amount * other.green),
            blue: blue * (1 - amount + amount * other.blue))
    }

    var luminance: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }
}
