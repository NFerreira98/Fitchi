import SwiftUI

/// How a scene is lit at a moment of the real day: a warm glow at dawn and dusk, the sun's arc
/// across the sky, and night (a darker world, the moon, stars and fireflies). Like the pet, a pure
/// function of the clock.
public struct SceneLight: Hashable, Sendable {
    /// 0 = full daylight … 1 = deep night.
    public var night: Double
    /// 0 = plain daylight … 1 = the strongest sunrise or sunset glow.
    public var warmth: Double
    /// How far the sun is across the sky, 0 (rising) … 1 (setting); nil while it's down.
    public var sun: Double?

    public init(night: Double = 0, warmth: Double = 0, sun: Double? = 0.5) {
        self.night = night
        self.warmth = warmth
        self.sun = sun
    }

    /// Midday: how backdrops look in the shop and previews.
    public static let day = SceneLight()
    public static let dawn = SceneLight(at: 6.6)
    public static let dusk = SceneLight(at: 19.4)
    public static let midnight = SceneLight(at: 0)

    public init(at date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        self.init(at: Double(parts.hour ?? 12) + Double(parts.minute ?? 0) / 60)
    }

    /// - Parameter hour: hours after midnight, 0..<24.
    public init(at hour: Double) {
        // Dark from 21:30 to 5:00, fading over two hours either side.
        let evening = Self.smooth((hour - 19.5) / 2)
        let morning = 1 - Self.smooth((hour - 5) / 2)
        night = max(evening, morning)
        // A glow centred on sunrise (6:30) and sunset (19:30).
        let dawnGlow = 1 - min(1, abs(hour - 6.5) / 1.2)
        let duskGlow = 1 - min(1, abs(hour - 19.3) / 1.6)
        warmth = max(0, dawnGlow, duskGlow)
        let progress = (hour - 6) / 14
        sun = (0...1).contains(progress) ? progress : nil
    }

    static func smooth(_ value: Double) -> Double {
        let clamped = min(1, max(0, value))
        return clamped * clamped * (3 - 2 * clamped)
    }
}

/// What a backdrop is drawn for: the animation clock (seconds; 0 for a still picture) and light.
struct SceneWorld {
    var time: Double
    var light: SceneLight
    var season: Season = .summer

    static let still = SceneWorld(time: 0, light: .day)

    /// A plant colour as it looks this time of year.
    func greenery(_ color: Color) -> Color { season.greenery(color) }

    /// A gentle −1…1 wave, offset by `phase` so neighbours don't move in step.
    func wave(_ speed: Double, _ phase: Double = 0) -> Double { sin(time * speed + phase) }

    /// 0..<1 repeating every `period` seconds.
    func cycle(_ period: Double, offset: Double = 0) -> Double {
        let value = (time / period + offset).truncatingRemainder(dividingBy: 1)
        return value < 0 ? value + 1 : value
    }
}
