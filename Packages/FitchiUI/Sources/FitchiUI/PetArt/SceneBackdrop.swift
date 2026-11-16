import FitchiCore
import SwiftUI

/// A background the pet stands in front of. Backdrops are unlockable on their own and work with
/// any pet; Core only knows the id.
public struct SceneBackdrop: View {
    /// Raw values are the shop item ids (`Catalog.defaultBackdropID` for the meadow).
    public enum Kind: String, CaseIterable, Sendable {
        case meadow = "backdrop-meadow"
        case pond = "backdrop-pond"
        case snowyHill = "backdrop-snowy-hill"
        case beach = "backdrop-beach"
        case starryNight = "backdrop-starry-night"
        case forest = "backdrop-forest"
        case bedroom = "backdrop-bedroom"
        case livingRoom = "backdrop-living-room"
        case kitchen = "backdrop-kitchen"
        case garden = "backdrop-garden"
        case playroom = "backdrop-playroom"

        /// Accepts shop ids ("backdrop-pond") and short names ("pond").
        public init(id: String) {
            self = Kind(rawValue: id) ?? Kind(rawValue: "backdrop-\(id)") ?? .meadow
        }
    }

    private let kind: Kind
    private let time: TimeInterval
    private let light: SceneLight
    private let season: Season
    private let weather: Weather

    /// - Parameters:
    ///   - time: an animation clock in seconds (clouds drift, grass sways); 0 is a still picture.
    ///   - light: the time of day to light the scene for.
    ///   - season: the time of year (meadow, pond and forest change with it); summer is as drawn.
    ///   - weather: rain, wind, snow or grey skies (`Weather(at:season:)`); clear in the shop.
    public init(
        _ kind: Kind, time: TimeInterval = 0, light: SceneLight = .day, season: Season = .summer,
        weather: Weather = .clear
    ) {
        self.weather = weather
        self.kind = kind
        self.time = time
        self.light = light
        self.season = season
    }

    public init(id: String) {
        self.init(Kind(id: id))
    }

    public var body: some View {
        Canvas { context, size in
            // Width-based art space; the ground stretches to fill any extra height.
            let scale = size.width / 100
            context.scaleBy(x: scale, y: scale)
            let height = size.height / scale
            // The starry night is always night; everywhere else follows the real clock.
            let world = SceneWorld(
                time: time, light: kind == .starryNight ? .day : light, season: kind.hasSeasons ? season : .summer,
                weather: weather.adapted(to: kind))
            switch kind {
            case .meadow: Meadow.draw(context, height: height, world: world)
            case .pond: Pond.draw(context, height: height, world: world)
            case .snowyHill: SnowyHill.draw(context, height: height, world: world)
            case .beach: Beach.draw(context, height: height, world: world)
            case .starryNight: StarryNight.draw(context, height: height, world: world)
            case .forest: Forest.draw(context, height: height, world: world)
            case .bedroom: Bedroom.draw(context, height: height, world: world)
            case .livingRoom: LivingRoom.draw(context, height: height, world: world)
            case .kitchen: Kitchen.draw(context, height: height, world: world)
            case .garden: Garden.draw(context, height: height, world: world)
            case .playroom: Playroom.draw(context, height: height, world: world)
            }
            if !kind.isIndoor {
                if kind.hasSeasons { SeasonArt.draw(context, height: height, horizon: kind.horizon, world: world) }
                WeatherArt.draw(context, height: height, horizon: kind.horizon, world: world)
                Haze.draw(context, horizon: kind.horizon, world: world)
                if kind != .starryNight {
                    Air.rays(context, horizon: kind.horizon, height: height, world: world)
                    Air.motes(context, height: height, world: world)
                }
            }
            Air.vignette(context, height: height, indoor: kind.isIndoor)
            Lighting.apply(context, height: height, world: world, indoor: kind.isIndoor)
            // Lights that shine through the dark: the moon and stars, fireflies, lamps.
            switch kind {
            case .meadow, .pond, .snowyHill, .beach, .forest, .garden:
                Sky.nightSky(context, world: world)
                if kind != .snowyHill && kind != .beach && world.season != .winter {
                    Fireflies.draw(
                        context, world: world, around: 60, strength: world.light.night * (1 - world.weather.rain))
                }
            case .bedroom: Lighting.lamp(context, at: Bedroom.lamp, world: world)
            case .livingRoom: Lighting.lamp(context, at: LivingRoom.lamp, world: world)
            case .kitchen: Kitchen.underCounterLights(context, world: world)
            case .playroom: Lighting.lamp(context, at: Playroom.lamp, world: world)
            case .starryNight: break
            }
        }
        .accessibilityHidden(true)
    }
}

extension SceneBackdrop.Kind {
    var isIndoor: Bool { self == .bedroom || self == .livingRoom || self == .kitchen || self == .playroom }

    /// Whether little visitors (butterflies, birds, fireflies) drop by in this scene.
    public var hasVisitors: Bool { !isIndoor }

    /// What drops by: a bird in the snow (or any winter scene), fireflies on warm nights,
    /// butterflies otherwise.
    public func visitor(in light: SceneLight, season: Season = .summer) -> Visitor.Kind {
        let wintry = self == .snowyHill || (hasSeasons && season == .winter)
        if self == .starryNight || (light.night > 0.6 && !wintry) { return .firefly }
        return wintry ? .bird : .butterfly
    }
}

enum Sky {
    static func draw(_ context: GraphicsContext, top: Color, bottom: Color, horizon: CGFloat, world: SceneWorld) {
        let sky = Path(CGRect(x: 0, y: 0, width: 100, height: horizon + 2))
        context.fill(
            sky,
            with: .linearGradient(
                Gradient(colors: [top, bottom]), startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)))
        if let progress = world.light.sun {
            // An arc from low on the left at sunrise, high at noon, down on the right at sunset,
            // drawn before the hills so it rises and sets behind them.
            let center = sunCenter(horizon: horizon, progress: progress)
            let warmth = world.light.warmth
            let sun = Color(red: 1, green: 0.9 - 0.3 * warmth, blue: 0.5 - 0.25 * warmth)
            // Hidden behind grey cloud on a dull day.
            let shows = 1 - 0.85 * world.weather.overcast
            context.fill(Path(ellipse: center, rx: 10, ry: 10), with: .color(sun.opacity(0.25 * shows)))
            context.fill(Path(ellipse: center, rx: 6, ry: 6), with: .color(sun.opacity(shows)))
        }
        // Clouds drift slowly across and wrap around.
        cloud(context, at: CGPoint(x: drift(22, speed: 0.35, world), y: 16), size: 1)
        cloud(context, at: CGPoint(x: drift(78, speed: 0.22, world), y: 26), size: 0.7)
    }

    /// Where the sun is, `progress` 0 (rising, left) … 1 (setting, right).
    static func sunCenter(horizon: CGFloat, progress: Double) -> CGPoint {
        // Peaks at y = 20 rather than the very top, clear of the iPhone's status bar.
        CGPoint(x: 8 + 84 * progress, y: horizon - 2 - sin(.pi * progress) * (horizon - 22))
    }

    /// An x position that moves right at `speed` units a second, wrapping from 120 back to −20.
    static func drift(_ start: CGFloat, speed: CGFloat, _ world: SceneWorld) -> CGFloat {
        let travelled = (start + 20 + speed * CGFloat(world.time)).truncatingRemainder(dividingBy: 140)
        return (travelled < 0 ? travelled + 140 : travelled) - 20
    }

    static func cloud(_ context: GraphicsContext, at center: CGPoint, size: CGFloat, color: Color = .white) {
        var puff = Path()
        for (deltaX, deltaY, radius) in [(-7.0, 1.0, 5.0), (0, -2, 7), (8, 1, 5.5), (2, 3, 5)] {
            puff.addEllipse(
                in: CGRect(
                    x: center.x + (deltaX - radius) * size, y: center.y + (deltaY - radius) * size,
                    width: radius * 2 * size, height: radius * 2 * size
                ))
        }
        context.fill(puff, with: .color(color.opacity(0.9)))
    }

    /// Star positions; the size is in `starSizes`.
    static let stars: [CGPoint] = [
        CGPoint(x: 12, y: 10), CGPoint(x: 30, y: 22), CGPoint(x: 46, y: 8), CGPoint(x: 60, y: 28),
        CGPoint(x: 22, y: 34), CGPoint(x: 92, y: 30), CGPoint(x: 54, y: 18),
    ]
    static let starSizes: [CGFloat] = [1.6, 1.1, 1.8, 1.0, 1.2, 1.3, 0.9]

    /// Twinkling stars, `strength` 0…1.
    static func drawStars(_ context: GraphicsContext, world: SceneWorld, strength: Double) {
        guard strength > 0.02 else { return }
        for (index, (center, size)) in zip(stars, starSizes).enumerated() {
            let twinkle = 0.55 + 0.45 * world.wave(1.1 + Double(index) * 0.37, Double(index) * 2.1)
            context.fill(
                Sparkles.star(at: center, size: size),
                with: .color(Color(red: 1, green: 0.96, blue: 0.84).opacity(twinkle * strength)))
        }
    }

    /// The moon and stars over an outdoor scene as night falls (drawn after the dark is laid on).
    static func nightSky(_ context: GraphicsContext, world: SceneWorld) {
        let night = world.light.night * (1 - 0.9 * world.weather.overcast)
        guard night > 0.02 else { return }
        drawStars(context, world: world, strength: night)
        let moon = CGPoint(x: 72, y: 19)
        context.fill(
            Path(ellipse: moon, rx: 9, ry: 9), with: .color(Color(red: 1, green: 0.96, blue: 0.8).opacity(0.18 * night))
        )
        context.fill(
            Path(ellipse: moon, rx: 5, ry: 5), with: .color(Color(red: 1, green: 0.96, blue: 0.8).opacity(night)))
    }
}

/// Lays dawn, dusk and night over a finished scene.
enum Lighting {
    static func apply(_ context: GraphicsContext, height: CGFloat, world: SceneWorld, indoor: Bool) {
        let light = world.light
        let all = Path(CGRect(x: 0, y: 0, width: 100, height: height))
        var multiply = context
        multiply.blendMode = .multiply
        if light.warmth > 0.01 {
            if !indoor {
                // A sunrise/sunset glow along the horizon.
                context.fill(
                    Path(CGRect(x: 0, y: 0, width: 100, height: 60)),
                    with: .linearGradient(
                        Gradient(colors: [.clear, Color(red: 1, green: 0.55, blue: 0.35).opacity(0.45 * light.warmth)]),
                        startPoint: CGPoint(x: 0, y: 8), endPoint: CGPoint(x: 0, y: 58)))
            }
            multiply.fill(
                all,
                with: .color(Color(red: 1, green: 0.8, blue: 0.66).opacity((indoor ? 0.3 : 0.5) * light.warmth)))
        }
        if light.night > 0.01 {
            let shade = indoor ? Color(red: 0.42, green: 0.38, blue: 0.55) : Color(red: 0.2, green: 0.25, blue: 0.5)
            multiply.fill(all, with: .color(shade.opacity((indoor ? 0.6 : 0.78) * light.night)))
        }
    }

    /// A warm pool of lamplight that grows as the room gets dark.
    static func lamp(_ context: GraphicsContext, at center: CGPoint, world: SceneWorld) {
        let night = world.light.night
        guard night > 0.02 else { return }
        let glow = Color(red: 1, green: 0.86, blue: 0.55)
        context.fill(
            Path(ellipse: center, rx: 34, ry: 34),
            with: .radialGradient(
                Gradient(colors: [glow.opacity(0.5 * night), glow.opacity(0.15 * night), .clear]), center: center,
                startRadius: 0, endRadius: 34))
        context.fill(
            Path(ellipse: center, rx: 3, ry: 3), with: .color(Color(red: 1, green: 0.97, blue: 0.85).opacity(night)))
    }
}

/// Glowing dots that drift and blink low over the grass.
enum Fireflies {
    static let spots: [(CGFloat, CGFloat)] = [(16, -2), (84, -8), (66, 10), (34, 16), (50, -12)]

    static func draw(_ context: GraphicsContext, world: SceneWorld, around baseY: CGFloat, strength: Double) {
        guard strength > 0.05 else { return }
        let glow = Color(red: 1, green: 0.95, blue: 0.48)
        for (index, (x, y)) in spots.enumerated() {
            let phase = Double(index) * 1.9
            let center = CGPoint(
                x: x + 6 * world.wave(0.3, phase), y: baseY + y + 3 * world.wave(0.45, phase * 1.7))
            let blink = max(0, world.wave(1.6, phase)) * 0.8 + 0.2
            context.fill(Path(ellipse: center, rx: 2.8, ry: 2.8), with: .color(glow.opacity(0.28 * blink * strength)))
            context.fill(Path(ellipse: center, rx: 1, ry: 1), with: .color(glow.opacity(blink * strength)))
        }
    }
}
