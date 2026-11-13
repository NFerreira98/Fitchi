import Foundation

/// The day's weather in the pet's world: mostly fair, now and then a grey day, a shower, a windy
/// spell or (in winter) snow. It isn't real-world weather: like the light and the seasons it is a
/// pure function of the date, so the watch and the phone always agree and nothing is stored.
public struct Weather: Hashable, Sendable {
    public enum Kind: String, CaseIterable, Codable, Sendable {
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
        var roll = StableNoise.value(seed, day)
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
        let begins = 7 + StableNoise.value(seed &+ 1, day) * 11
        let lasts = 2 + StableNoise.value(seed &+ 2, day) * 4
        let into = min(hour - begins, begins + lasts - hour)
        let amount = StableNoise.smooth(into / 0.5)
        if amount > 0 {
            self.init(kind: kind, amount: amount)
        } else {
            // Grey skies around a shower; a windy or snowy day is fair outside its spell.
            self.init(kind: kind == .rain ? .cloudy : .clear, amount: kind == .rain ? 0.7 : 0)
        }
    }

    /// The kind that's really happening: a spell only counts once it has properly started.
    public var settledKind: Kind { amount >= 0.3 ? kind : .clear }
}
