import SwiftUI

/// The day's weather in the pet's world: mostly fair, now and then a grey day, a shower, a windy
/// spell or (in winter) snow. It isn't real-world weather: like the light and the seasons it is a
/// pure function of the date, so the watch and the phone always agree and nothing is stored.
public struct Weather: Hashable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case clear, cloudy, rain, wind, snow
    }

    public var kind: Kind
    /// 0…1: how strong it is right now (spells build up and die down over half an hour).
    public var amount: Double

    public init(kind: Kind, amount: Double = 1) {
        self.kind = kind
        self.amount = amount
    }

    public static let clear = Weather(kind: .clear, amount: 0)

    /// Odds of each kind of day, by season. Whatever's left over is a clear day.
    static func odds(in season: Season) -> [(Kind, Double)] {
        switch season {
        case .spring: [(.rain, 0.22), (.cloudy, 0.18), (.wind, 0.14)]
        case .summer: [(.rain, 0.12), (.cloudy, 0.12), (.wind, 0.1)]
        case .autumn: [(.rain, 0.22), (.cloudy, 0.2), (.wind, 0.2)]
        case .winter: [(.snow, 0.26), (.cloudy, 0.24), (.wind, 0.12)]
        }
    }

    /// The weather at `date`. Each day rolls its kind; rain, wind and snow come as one spell of
    /// 2–6 hours somewhere between 7:00 and midnight, with grey skies either side of a shower.
    public init(at date: Date, season: Season, calendar: Calendar = .current) {
        let start = calendar.startOfDay(for: date)
        let day = Int((start.timeIntervalSinceReferenceDate / 86_400).rounded())
        let seed = 0x5EA7
        var roll = PetLife.noise(seed, day)
        var kind = Kind.clear
        for (candidate, chance) in Self.odds(in: season) {
            if roll < chance {
                kind = candidate
                break
            }
            roll -= chance
        }
        guard kind != .clear, kind != .cloudy else {
            self.init(kind: kind, amount: kind == .clear ? 0 : 1)
            return
        }
        let hour = date.timeIntervalSince(start) / 3_600
        let begins = 7 + PetLife.noise(seed &+ 1, day) * 11
        let lasts = 2 + PetLife.noise(seed &+ 2, day) * 4
        let into = min(hour - begins, begins + lasts - hour)
        let amount = SceneLight.smooth(into / 0.5)
        if amount > 0 {
            self.init(kind: kind, amount: amount)
        } else {
            // Grey skies around a shower; a windy or snowy day is fair outside its spell.
            self.init(kind: kind == .rain ? .cloudy : .clear, amount: kind == .rain ? 0.7 : 0)
        }
    }

    /// The same weather as a particular scene has it: the starry night is always clear, it
    /// snows rather than rains on the snowy hill, and it never snows on the beach.
    public func adapted(to kind: SceneBackdrop.Kind) -> Weather {
        switch (kind, self.kind) {
        case (.starryNight, _): .clear
        case (.snowyHill, .rain): Weather(kind: .snow, amount: amount)
        case (.beach, .snow): Weather(kind: .rain, amount: amount)
        default: self
        }
    }

    /// How grey the sky is, 0…1.
    var overcast: Double {
        switch kind {
        case .clear: 0
        case .cloudy: 0.55 * amount
        case .rain, .snow: amount
        case .wind: 0.25 * amount
        }
    }

    var rain: Double { kind == .rain ? amount : 0 }
    var snow: Double { kind == .snow ? amount : 0 }
    var wind: Double { kind == .wind ? amount : kind == .rain ? 0.3 * amount : 0 }
}

extension SceneWorld {
    /// A sway that grows gustier in the wind and leans the way it blows (−1…1 calm, more in a gale).
    func sway(_ speed: Double, _ phase: Double = 0) -> Double {
        let wind = weather.wind
        return wave(speed, phase) * (1 + 1.4 * wind) + wave(speed * 2.3, phase * 1.7) * 0.5 * wind + 1.1 * wind
    }
}

/// Drawing the weather over a scene (before the time-of-day light is laid on).
enum WeatherArt {
    static func draw(_ context: GraphicsContext, height: CGFloat, horizon: CGFloat, world: SceneWorld) {
        let weather = world.weather
        if weather.overcast > 0.01 { overcast(context, height: height, horizon: horizon, world: world) }
        if weather.wind > 0.3, world.time > 0 { gusts(context, world: world) }
        if weather.rain > 0.01 {
            puddles(context, horizon: horizon, world: world)
            rain(context, height: height, world: world, in: CGRect(x: 0, y: 0, width: 100, height: height))
        }
        if weather.snow > 0.01, world.time > 0 {
            SnowyHill.snowfall(context, height: height, world: world, count: Int(4 + 6 * weather.snow))
        }
    }

    /// Grey clouds rolling over and a duller sky.
    static func overcast(_ context: GraphicsContext, height: CGFloat, horizon: CGFloat, world: SceneWorld) {
        let grey = world.weather.overcast
        context.fill(
            Path(CGRect(x: 0, y: 0, width: 100, height: horizon + 4)),
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.6, green: 0.64, blue: 0.7).opacity(0.7 * grey), .clear]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon + 4)))
        var cloudy = context
        cloudy.opacity = grey
        let shade = Color(red: 0.8, green: 0.83, blue: 0.88)
        // A bank of cloud, evenly spaced along the 140-wide drift loop so the sky stays covered.
        for index in 0..<6 {
            let x = Sky.drift(CGFloat(index) * 140 / 6, speed: 0.45, world)
            let y: CGFloat = index.isMultiple(of: 2) ? 7 : 15
            Sky.cloud(cloudy, at: CGPoint(x: x, y: y), size: index.isMultiple(of: 2) ? 1.4 : 1.1, color: shade)
        }
        var dull = context
        dull.blendMode = .multiply
        dull.fill(
            Path(CGRect(x: 0, y: 0, width: 100, height: height)),
            with: .color(Color(red: 0.82, green: 0.85, blue: 0.9).opacity(0.6 * grey)))
    }

    /// Slanted streaks falling through `rect`, each on its own short loop.
    static func rain(_ context: GraphicsContext, height: CGFloat, world: SceneWorld, in rect: CGRect) {
        let amount = world.weather.rain
        guard world.time > 0 else { return }
        let drops = Int(16 + 34 * amount)
        let slant = 0.25 + 0.4 * world.weather.wind
        var streaks = Path()
        for index in 0..<drops {
            let across = PetLife.noise(41, index)
            let period = 0.55 + 0.3 * PetLife.noise(42, index)
            let fall = world.cycle(period, offset: PetLife.noise(43, index))
            let top = rect.minY - 6 + (rect.height + 8) * fall
            let x = rect.minX + rect.width * across - slant * (top - rect.minY) * 0.3
            let length = 4.5 * (rect.width / 100) + 1
            streaks.move(to: CGPoint(x: x, y: top))
            streaks.addLine(to: CGPoint(x: x - slant * length, y: top + length))
        }
        var clipped = context
        clipped.clip(to: Path(rect))
        clipped.stroke(
            streaks, with: .color(Color(red: 0.85, green: 0.92, blue: 1).opacity(0.75 * amount)),
            style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
    }

    /// Rings spreading where the drops land.
    static func puddles(_ context: GraphicsContext, horizon: CGFloat, world: SceneWorld) {
        guard world.time > 0 else { return }
        for index in 0..<6 {
            let spread = world.cycle(1.1 + 0.2 * Double(index), offset: Double(index) * 0.37)
            let center = CGPoint(x: 8 + Double(index) * 16.5, y: horizon + 9 + Double((index * 7) % 5) * 6.5)
            let width = 1.5 + 4 * spread
            context.stroke(
                Path(ellipse: center, rx: width, ry: width * 0.35),
                with: .color(.white.opacity(0.55 * (1 - spread) * world.weather.rain)), lineWidth: 0.5)
        }
    }

    /// Wisps of wind streaming across the sky, and a leaf or two tumbling past.
    static func gusts(_ context: GraphicsContext, world: SceneWorld) {
        let wind = world.weather.wind
        for index in 0..<3 {
            let progress = world.cycle(2.6 + Double(index) * 0.7, offset: Double(index) * 0.3)
            let x = -30 + 160 * progress
            let y = 14 + Double(index) * 11
            var wisp = Path()
            wisp.move(to: CGPoint(x: x, y: y))
            wisp.addCurve(
                to: CGPoint(x: x + 22, y: y), control1: CGPoint(x: x + 7, y: y - 3),
                control2: CGPoint(x: x + 14, y: y + 3))
            context.stroke(
                wisp, with: .color(.white.opacity(0.55 * wind * sin(.pi * progress))),
                style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        }
        if world.season == .summer || world.season == .winter {
            SeasonArt.drift(context, height: 100, world: world, petal: false)
        }
    }

    /// Weather seen through a window: grey glass, streaks of rain or falling flakes.
    static func window(_ glass: GraphicsContext, rect: CGRect, world: SceneWorld) {
        let weather = world.weather
        guard weather.overcast > 0.01 else { return }
        glass.fill(Path(rect), with: .color(Color(red: 0.62, green: 0.66, blue: 0.72).opacity(0.6 * weather.overcast)))
        if weather.rain > 0.01 {
            rain(glass, height: rect.height, world: world, in: rect)
        }
        if weather.snow > 0.01, world.time > 0 {
            for index in 0..<5 {
                let fall = world.cycle(3 + Double(index) * 0.6, offset: Double(index) * 0.29)
                let point = CGPoint(
                    x: rect.minX + rect.width * (0.1 + 0.2 * Double(index)) + 1.5 * world.wave(0.8, Double(index)),
                    y: rect.minY + rect.height * fall)
                glass.fill(Path(ellipse: point, rx: 0.7, ry: 0.7), with: .color(.white.opacity(0.9)))
            }
        }
    }
}
