import SwiftUI

/// The time of year, which dresses the green outdoor scenes: blossom drifting in spring, golden
/// grass and falling leaves in autumn, frost and a little snow in winter. Like the light, a pure
/// function of the date (and which half of the world you're in).
public enum Season: String, CaseIterable, Sendable {
    case spring, summer, autumn, winter

    /// Countries mostly or wholly south of the equator, where the seasons are the other way round.
    static let southernRegions: Set<String> = [
        "AR", "AU", "BO", "BR", "BW", "CL", "FJ", "LS", "MG", "MU", "MZ", "NA", "NC", "NZ", "PE", "PY", "SZ", "UY",
        "ZA", "ZW",
    ]

    /// - Parameter southern: nil works it out from the device's region.
    public init(at date: Date, calendar: Calendar = .current, southern: Bool? = nil) {
        let month = calendar.component(.month, from: date)
        let isSouthern = southern ?? Self.southernRegions.contains(Locale.current.region?.identifier ?? "")
        // Meteorological seasons: March–May is spring in the north.
        let north: [Season] = [.winter, .spring, .summer, .autumn]
        let index = (month % 12) / 3
        self = north[(index + (isSouthern ? 2 : 0)) % 4]
    }

    /// Autumn trees turn different colours: orange, red and gold.
    static let autumnLeaves = [
        Color(red: 0.93, green: 0.55, blue: 0.2), Color(red: 0.84, green: 0.33, blue: 0.2),
        Color(red: 0.96, green: 0.74, blue: 0.27),
    ]

    /// Season to season, grass and leaves change colour: summer is the art as drawn.
    func greenery(_ color: Color) -> Color {
        switch self {
        case .spring: color.mix(with: Color(red: 0.75, green: 0.95, blue: 0.5), by: 0.18)
        case .summer: color
        case .autumn: color.mix(with: Color(red: 0.98, green: 0.62, blue: 0.2), by: 0.55)
        case .winter: color.mix(with: Color(red: 0.9, green: 0.94, blue: 1), by: 0.62)
        }
    }
}

extension SceneBackdrop.Kind {
    /// The green scenes that change with the seasons (the snowy hill is always winter, the beach
    /// always summer).
    var hasSeasons: Bool { self == .meadow || self == .pond || self == .forest }

    /// Where the far edge of the ground meets the sky, in the 100-wide art space.
    var horizon: CGFloat {
        switch self {
        case .pond: 50
        case .snowyHill: 54
        case .beach: 46
        default: 56
        }
    }
}

/// What drifts through a scene in each season.
enum SeasonArt {
    static func draw(_ context: GraphicsContext, height: CGFloat, horizon: CGFloat, world: SceneWorld) {
        switch world.season {
        case .spring: drift(context, height: height, world: world, petal: true)
        case .autumn: drift(context, height: height, world: world, petal: false)
        case .winter:
            frost(context, height: height, horizon: horizon)
            if world.time > 0 { SnowyHill.snowfall(context, height: height, world: world, count: 6) }
        case .summer: break
        }
    }

    /// Blossom petals (or autumn leaves) tumbling across on the breeze.
    static func drift(_ context: GraphicsContext, height: CGFloat, world: SceneWorld, petal: Bool) {
        guard world.time > 0 else { return }
        let colors: [Color] =
            petal
            ? [Color(red: 1, green: 0.78, blue: 0.86), Color(red: 1, green: 0.9, blue: 0.94)]
            : [
                Color(red: 0.91, green: 0.55, blue: 0.2), Color(red: 0.8, green: 0.36, blue: 0.2),
                Color(red: 0.95, green: 0.75, blue: 0.3),
            ]
        for index in 0..<5 {
            let period = 9.0 + Double(index) * 1.7
            let progress = world.cycle(period, offset: Double(index) * 0.23)
            let x = -6 + 112 * progress
            let y = 12 + Double(index) * 9 + progress * 26 + 3 * sin(progress * .pi * 4 + Double(index))
            guard y < Double(height) else { continue }
            let angle = 180 * progress * (index.isMultiple(of: 2) ? 1 : -1) * 3
            let size = petal ? 1.5 : 1.7
            context.fill(
                Path(ellipse: CGPoint(x: x, y: y), rx: size, ry: size * 0.55, degrees: angle),
                with: .color(colors[index % colors.count]))
        }
    }

    /// A pale crust of frost settling on the far ground and the nearest grass.
    static func frost(_ context: GraphicsContext, height: CGFloat, horizon: CGFloat) {
        context.fill(
            Path(CGRect(x: 0, y: horizon - 14, width: 100, height: height - horizon + 14)),
            with: .linearGradient(
                Gradient(colors: [.white.opacity(0), .white.opacity(0.28), .white.opacity(0.12)]),
                startPoint: CGPoint(x: 0, y: horizon - 14), endPoint: CGPoint(x: 0, y: height)))
    }
}

/// Distance fades things toward the sky: the far hills and the ground at the horizon are paler
/// than what's close, so the scene has depth.
enum Haze {
    static func draw(_ context: GraphicsContext, horizon: CGFloat, world: SceneWorld) {
        // Thicker in the cool of morning and evening, barely there at noon.
        let strength = 0.2 + 0.15 * world.light.warmth
        let mist = Color(red: 0.94, green: 0.97, blue: 1)
        context.fill(
            Path(CGRect(x: 0, y: horizon - 20, width: 100, height: 34)),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: mist.opacity(0), location: 0),
                    .init(color: mist.opacity(strength), location: 0.58),
                    .init(color: mist.opacity(0), location: 1),
                ]),
                startPoint: CGPoint(x: 0, y: horizon - 20), endPoint: CGPoint(x: 0, y: horizon + 14)))
    }
}

/// What walking leaves behind on a scene's ground.
enum Footing: Equatable {
    /// Footprints pressed into snow or sand.
    case prints(Color)
    /// Little puffs of dust kicked up from grass or earth.
    case puffs(Color)
    case none

    /// How long a mark stays.
    var lasting: TimeInterval {
        switch self {
        case .prints: 6
        case .puffs: 0.7
        case .none: 0
        }
    }
}

extension SceneBackdrop.Kind {
    func footing(in season: Season) -> Footing {
        let snow = Footing.prints(Color(red: 0.62, green: 0.71, blue: 0.86))
        if hasSeasons, season == .winter { return snow }
        switch self {
        case .snowyHill: return snow
        case .beach: return .prints(Color(red: 0.79, green: 0.64, blue: 0.42))
        case .bedroom, .livingRoom, .kitchen: return .none
        case .forest: return .puffs(Color(red: 0.72, green: 0.6, blue: 0.45))
        case .meadow, .pond, .starryNight: return .puffs(Color(red: 0.93, green: 0.9, blue: 0.8))
        }
    }
}

extension SceneLight {
    /// The pet stands in the same light as its scene: a little warmer at dawn and dusk, cooler
    /// and dimmer at night (but always easy to see). Multiply the pet's colours by this.
    func petTint(indoor: Bool) -> Color {
        let night = indoor ? (0.9, 0.86, 0.82) : (0.72, 0.76, 0.92)
        let glow = (1.0, 0.9, 0.8)
        func channel(_ dark: Double, _ warm: Double) -> Double {
            let lit = 1 + (warm - 1) * warmth * 0.5
            return lit + (dark - lit) * self.night
        }
        return Color(
            red: channel(night.0, glow.0), green: channel(night.1, glow.1), blue: channel(night.2, glow.2))
    }
}
