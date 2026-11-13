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

        /// Accepts shop ids ("backdrop-pond") and short names ("pond").
        public init(id: String) {
            self = Kind(rawValue: id) ?? Kind(rawValue: "backdrop-\(id)") ?? .meadow
        }
    }

    private let kind: Kind
    private let time: TimeInterval
    private let light: SceneLight
    private let season: Season

    /// - Parameters:
    ///   - time: an animation clock in seconds (clouds drift, grass sways); 0 is a still picture.
    ///   - light: the time of day to light the scene for.
    ///   - season: the time of year (meadow, pond and forest change with it); summer is as drawn.
    public init(_ kind: Kind, time: TimeInterval = 0, light: SceneLight = .day, season: Season = .summer) {
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
                time: time, light: kind == .starryNight ? .day : light, season: kind.hasSeasons ? season : .summer)
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
            }
            if !kind.isIndoor {
                if kind.hasSeasons { SeasonArt.draw(context, height: height, horizon: kind.horizon, world: world) }
                Haze.draw(context, horizon: kind.horizon, world: world)
            }
            Lighting.apply(context, height: height, world: world, indoor: kind.isIndoor)
            // Lights that shine through the dark: the moon and stars, fireflies, lamps.
            switch kind {
            case .meadow, .pond, .snowyHill, .beach, .forest:
                Sky.nightSky(context, world: world)
                if kind != .snowyHill && kind != .beach && world.season != .winter {
                    Fireflies.draw(context, world: world, around: 60, strength: world.light.night)
                }
            case .bedroom: Lighting.lamp(context, at: Bedroom.lamp, world: world)
            case .livingRoom: Lighting.lamp(context, at: LivingRoom.lamp, world: world)
            case .kitchen: Kitchen.underCounterLights(context, world: world)
            case .starryNight: break
            }
        }
        .accessibilityHidden(true)
    }
}

extension SceneBackdrop.Kind {
    var isIndoor: Bool { self == .bedroom || self == .livingRoom || self == .kitchen }

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
            let center = CGPoint(x: 8 + 84 * progress, y: horizon - 2 - sin(.pi * progress) * (horizon - 14))
            let warmth = world.light.warmth
            let sun = Color(red: 1, green: 0.9 - 0.3 * warmth, blue: 0.5 - 0.25 * warmth)
            context.fill(Path(ellipse: center, rx: 10, ry: 10), with: .color(sun.opacity(0.25)))
            context.fill(Path(ellipse: center, rx: 6, ry: 6), with: .color(sun))
        }
        // Clouds drift slowly across and wrap around.
        cloud(context, at: CGPoint(x: drift(22, speed: 0.35, world), y: 16), size: 1)
        cloud(context, at: CGPoint(x: drift(78, speed: 0.22, world), y: 26), size: 0.7)
    }

    /// An x position that moves right at `speed` units a second, wrapping from 120 back to −20.
    static func drift(_ start: CGFloat, speed: CGFloat, _ world: SceneWorld) -> CGFloat {
        let travelled = (start + 20 + speed * CGFloat(world.time)).truncatingRemainder(dividingBy: 140)
        return (travelled < 0 ? travelled + 140 : travelled) - 20
    }

    static func cloud(_ context: GraphicsContext, at center: CGPoint, size: CGFloat) {
        var puff = Path()
        for (deltaX, deltaY, radius) in [(-7.0, 1.0, 5.0), (0, -2, 7), (8, 1, 5.5), (2, 3, 5)] {
            puff.addEllipse(
                in: CGRect(
                    x: center.x + (deltaX - radius) * size, y: center.y + (deltaY - radius) * size,
                    width: radius * 2 * size, height: radius * 2 * size
                ))
        }
        context.fill(puff, with: .color(.white.opacity(0.9)))
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
        let night = world.light.night
        guard night > 0.02 else { return }
        drawStars(context, world: world, strength: night)
        let moon = CGPoint(x: 72, y: 12)
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

private enum Meadow {
    static func draw(_ context: GraphicsContext, height: CGFloat, world: SceneWorld) {
        let horizon: CGFloat = 56
        Sky.draw(
            context, top: Color(red: 0.55, green: 0.80, blue: 1), bottom: Color(red: 0.86, green: 0.95, blue: 1),
            horizon: horizon, world: world)
        var hills = Path()
        hills.move(to: CGPoint(x: 0, y: horizon + 2))
        hills.addQuadCurve(to: CGPoint(x: 55, y: horizon - 2), control: CGPoint(x: 25, y: horizon - 14))
        hills.addQuadCurve(to: CGPoint(x: 100, y: horizon), control: CGPoint(x: 80, y: horizon - 12))
        hills.addLine(to: CGPoint(x: 100, y: height))
        hills.addLine(to: CGPoint(x: 0, y: height))
        context.fill(hills, with: .color(world.greenery(Color(red: 0.55, green: 0.80, blue: 0.50))))
        let field = Path(CGRect(x: 0, y: horizon + 6, width: 100, height: height))
        context.fill(
            field,
            with: .linearGradient(
                Gradient(colors: [
                    world.greenery(Color(red: 0.62, green: 0.87, blue: 0.48)),
                    world.greenery(Color(red: 0.48, green: 0.78, blue: 0.40)),
                ]),
                startPoint: CGPoint(x: 0, y: horizon + 6), endPoint: CGPoint(x: 0, y: height)
            ))
        Flora.tufts(
            context, rows: [horizon + 12, horizon + 24, horizon + 38],
            color: world.greenery(Color(red: 0.40, green: 0.68, blue: 0.34)), world: world)
        guard world.season != .winter else { return }
        Flora.flowers(
            context,
            at: [CGPoint(x: 10, y: horizon + 20), CGPoint(x: 88, y: horizon + 16), CGPoint(x: 82, y: horizon + 34)]
                + (world.season == .spring
                    ? [
                        CGPoint(x: 30, y: horizon + 30), CGPoint(x: 56, y: horizon + 14),
                        CGPoint(x: 64, y: horizon + 40),
                    ]
                    : []),
            world: world)
    }
}

private enum Pond {
    static func draw(_ context: GraphicsContext, height: CGFloat, world: SceneWorld) {
        let horizon: CGFloat = 50
        Sky.draw(
            context, top: Color(red: 1, green: 0.78, blue: 0.70), bottom: Color(red: 1, green: 0.93, blue: 0.84),
            horizon: horizon, world: world)
        let bank = Path(CGRect(x: 0, y: horizon, width: 100, height: height))
        context.fill(bank, with: .color(world.greenery(Color(red: 0.56, green: 0.80, blue: 0.52))))
        let water = Path(ellipse: CGPoint(x: 50, y: horizon + 16), rx: 58, ry: 14)
        // In winter the pond freezes over: pale ice, no ripples.
        let frozen = world.season == .winter
        context.fill(
            water,
            with: .linearGradient(
                Gradient(
                    colors: [Color(red: 0.55, green: 0.85, blue: 0.95), Color(red: 0.36, green: 0.70, blue: 0.88)]
                        .map { frozen ? $0.mix(with: .white, by: 0.55) : $0 }),
                startPoint: CGPoint(x: 0, y: horizon + 2), endPoint: CGPoint(x: 0, y: horizon + 30)
            ))
        context.stroke(water, with: .color(Color(red: 0.42, green: 0.66, blue: 0.40)), lineWidth: 1.6)
        // Ripples spread out and fade, one after another.
        for (index, center) in [CGPoint(x: 30, y: horizon + 11), CGPoint(x: 68, y: horizon + 20)].enumerated()
        where !frozen {
            let spread = world.time == 0 ? 0.5 : world.cycle(3.6, offset: Double(index) * 0.5)
            let width = 5 + 10 * spread
            var ripple = Path()
            ripple.move(to: CGPoint(x: center.x - width / 2, y: center.y))
            ripple.addQuadCurve(
                to: CGPoint(x: center.x + width / 2, y: center.y), control: CGPoint(x: center.x, y: center.y - 1.5))
            context.stroke(
                ripple, with: .color(.white.opacity(0.8 * (1 - spread) + 0.1)),
                style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
        lilyPad(context, at: CGPoint(x: 16, y: horizon + 18 + 0.4 * world.wave(0.9)), size: 6)
        lilyPad(context, at: CGPoint(x: 84, y: horizon + 10 + 0.4 * world.wave(0.9, 2)), size: 5)
        reeds(context, baseX: 92, baseY: horizon + 6, sway: world.wave(1.1))
        reeds(context, baseX: 6, baseY: horizon + 4, sway: world.wave(1.1, 1.3))
        Flora.tufts(
            context, rows: [horizon + 36, horizon + 46],
            color: world.greenery(Color(red: 0.42, green: 0.68, blue: 0.38)),
            world: world)
    }

    static func lilyPad(_ context: GraphicsContext, at center: CGPoint, size: CGFloat) {
        var pad = Path()
        pad.addArc(center: center, radius: size, startAngle: .degrees(20), endAngle: .degrees(340), clockwise: false)
        pad.addLine(to: center)
        pad.closeSubpath()
        let squashed = pad.applying(
            CGAffineTransform(translationX: -center.x, y: -center.y)
                .concatenating(CGAffineTransform(scaleX: 1, y: 0.45))
                .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        )
        context.fill(squashed, with: .color(Color(red: 0.36, green: 0.72, blue: 0.40)))
        context.fill(
            Path(ellipse: CGPoint(x: center.x - size * 0.2, y: center.y - 1.5), rx: 1.6, ry: 1.3),
            with: .color(Color(red: 1, green: 0.7, blue: 0.8)))
    }

    /// Reeds leaning with the breeze, `sway` −1…1.
    static func reeds(_ context: GraphicsContext, baseX: CGFloat, baseY: CGFloat, sway: Double) {
        for (offset, tall) in [(-2.5, 16.0), (0, 22), (2.5, 14)] {
            let lean = CGFloat(sway) * tall * 0.07
            let tip = CGPoint(x: baseX + offset * 1.6 + lean, y: baseY - tall)
            var stem = Path()
            stem.move(to: CGPoint(x: baseX + offset, y: baseY))
            stem.addQuadCurve(to: tip, control: CGPoint(x: baseX + offset + lean * 0.3, y: baseY - tall / 2))
            context.stroke(
                stem, with: .color(Color(red: 0.36, green: 0.60, blue: 0.32)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            if tall > 15 {
                let head = Path(
                    roundedRect: CGRect(x: tip.x - 1.3, y: tip.y, width: 2.6, height: 6), cornerRadius: 1.3)
                context.fill(head, with: .color(Color(red: 0.55, green: 0.36, blue: 0.24)))
            }
        }
    }
}

enum Flora {
    /// Rows of grass tufts whose tips sway in a breeze that rolls across the field.
    static func tufts(_ context: GraphicsContext, rows: [CGFloat], color: Color, world: SceneWorld) {
        for (row, baseY) in rows.enumerated() {
            for column in 0..<6 {
                let x = CGFloat(column) * 18 + (row.isMultiple(of: 2) ? 6 : 14)
                let sway = CGFloat(world.wave(1.4, Double(x) * 0.12 + Double(row))) * 0.7
                var tuft = Path()
                tuft.move(to: CGPoint(x: x - 2, y: baseY))
                tuft.addLine(to: CGPoint(x: x - 1 + sway, y: baseY - 2.5))
                tuft.move(to: CGPoint(x: x, y: baseY))
                tuft.addLine(to: CGPoint(x: x + 0.5 + sway, y: baseY - 3.5))
                tuft.move(to: CGPoint(x: x + 2, y: baseY))
                tuft.addLine(to: CGPoint(x: x + 2.5 + sway, y: baseY - 2.2))
                context.stroke(tuft, with: .color(color), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
            }
        }
    }

    static func flowers(_ context: GraphicsContext, at points: [CGPoint], world: SceneWorld) {
        let petals = [Color(red: 1, green: 0.75, blue: 0.85), Color.white, Color(red: 1, green: 0.85, blue: 0.4)]
        for (index, base) in points.enumerated() {
            // A little nod in the breeze.
            let center = CGPoint(x: base.x + CGFloat(world.wave(1.2, Double(index) * 2)) * 0.5, y: base.y)
            for petal in 0..<5 {
                let angle = Double(petal) / 5 * 2 * .pi
                let spot = CGPoint(x: center.x + cos(angle) * 1.6, y: center.y + sin(angle) * 1.6)
                context.fill(Path(ellipse: spot, rx: 1.3, ry: 1.3), with: .color(petals[index % petals.count]))
            }
            context.fill(Path(ellipse: center, rx: 0.9, ry: 0.9), with: .color(Color(red: 1, green: 0.8, blue: 0.3)))
        }
    }
}
