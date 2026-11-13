import Foundation

/// What the world is like at the moment an egg hatches: the season, the weather and the time
/// of day. Special colourings and species affinities are matched against it.
public struct HatchMoment: Hashable, Sendable {
    public var season: Season
    public var weather: Weather.Kind
    public var time: TimeOfDay

    public init(season: Season, weather: Weather.Kind, time: TimeOfDay) {
        self.season = season
        self.weather = weather
        self.time = time
    }

    /// A fair summer's day: nothing special can hatch. The default where no moment is given.
    public static let plain = HatchMoment(season: .summer, weather: .clear, time: .day)

    /// The moment at `date`, with the same weather the scenes show. A spell only counts once it
    /// has properly set in (`Weather.settledKind`).
    public init(at date: Date, calendar: Calendar = .current, southern: Bool? = nil) {
        let season = Season(at: date, calendar: calendar, southern: southern)
        self.init(
            season: season, weather: Weather(at: date, season: season, calendar: calendar).settledKind,
            time: TimeOfDay(at: date, calendar: calendar))
    }
}

/// When something can happen: every condition given must hold (e.g. `weather: snow`, or
/// `time: night`). Loaded from `Content/species.json` as `"when": {...}`.
public struct HatchCondition: Codable, Hashable, Sendable {
    public var weather: Weather.Kind?
    public var time: TimeOfDay?
    public var season: Season?

    public init(weather: Weather.Kind? = nil, time: TimeOfDay? = nil, season: Season? = nil) {
        self.weather = weather
        self.time = time
        self.season = season
    }

    public var isEmpty: Bool { weather == nil && time == nil && season == nil }

    public func matches(_ moment: HatchMoment) -> Bool {
        (weather.map { $0 == moment.weather } ?? true) && (time.map { $0 == moment.time } ?? true)
            && (season.map { $0 == moment.season } ?? true)
    }
}

/// A species that turns up more often in certain conditions (penguins in the snow), within the
/// egg's rolled rarity. Rarity odds never change.
public struct SpeciesAffinity: Codable, Hashable, Sendable {
    public var when: HatchCondition
    /// Multiplier on the species' share of its rarity while `when` holds.
    public var boost: Double

    public init(when: HatchCondition, boost: Double) {
        self.when = when
        self.boost = boost
    }
}

extension Species {
    /// Colourings that can hatch any time.
    public var regularVariants: [ColorVariant] { variants.filter { $0.when == nil } }

    /// Colourings that only hatch in certain conditions.
    public var specialVariants: [ColorVariant] { variants.filter { $0.when != nil } }

    /// Colourings that can hatch at `moment`: the regular ones plus any special ones it matches.
    public func variants(at moment: HatchMoment) -> [ColorVariant] {
        variants.filter { $0.when?.matches(moment) ?? true }
    }

    /// How much more likely this species is at `moment` (1 normally).
    public func affinity(at moment: HatchMoment) -> Double {
        affinities.filter { $0.when.matches(moment) }.reduce(1) { $0 * $1.boost }
    }
}
