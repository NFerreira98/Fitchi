import Foundation

/// "2026-11-12": the local calendar day, used in ledger ids so daily rewards pay once per day.
public enum GameDay {
    public static func key(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// A stable number per day (and `salt`), for seeding that day's random picks.
    static func seed(for date: Date, calendar: Calendar, salt: UInt64) -> UInt64 {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let day = UInt64((parts.year ?? 0) * 10_000 + (parts.month ?? 0) * 100 + (parts.day ?? 0))
        return day &* 0x9E37_79B9 &+ salt
    }
}

/// Little gifts the pet finds a few times a day: a reason to glance at the watch between
/// workouts. Each opens at a slightly different time every day and stays for a while.
public struct MomentRules: Hashable, Sendable {
    public var version: Int
    /// Windows in minutes after midnight; one moment opens somewhere inside each.
    public var windows: [ClosedRange<Int>]
    /// How long a moment stays open, in minutes.
    public var openFor: Int
    public var pep: ClosedRange<Int>
    /// Chance of a lucky find, worth `luckyPep`.
    public var luckyChance: Double
    public var luckyPep: Int

    public static let v1 = MomentRules(
        version: 1, windows: [7 * 60...10 * 60, 11 * 60 + 30...14 * 60 + 30, 17 * 60...20 * 60 + 30], openFor: 120,
        pep: 5...12, luckyChance: 0.1, luckyPep: 25)

    /// Things a pet might turn up with. The last one is the lucky find.
    static let finds = [
        "a shiny pebble", "a lost button", "a four-leaf clover", "a pretty feather", "a tiny seashell",
        "a smooth acorn", "a sparkly marble",
    ]
    static let luckyFind = "a golden coin"
}

/// One gift moment.
public struct PetMoment: Hashable, Sendable, Identifiable {
    /// The ledger id of its gift: "moment:2026-11-12:1".
    public var id: String
    public var opens: Date
    public var closes: Date
    /// "a shiny pebble".
    public var find: String
    public var pep: Int
    public var isLucky: Bool

    public func isOpen(at date: Date) -> Bool { opens <= date && date < closes }
}

public enum PetMoments {
    /// The day's moments, earliest first. The same on every device.
    public static func moments(on day: Date, calendar: Calendar, rules: MomentRules = .v1) -> [PetMoment] {
        let midnight = calendar.startOfDay(for: day)
        let key = GameDay.key(for: day, calendar: calendar)
        return rules.windows.enumerated().map { index, window in
            var rng = SeededRandom(
                seed: GameDay.seed(for: day, calendar: calendar, salt: UInt64(rules.version * 100 + index)))
            let latestStart = max(window.lowerBound, window.upperBound - rules.openFor)
            let start = Int.random(in: window.lowerBound...latestStart, using: &rng)
            let lucky = Double.random(in: 0..<1, using: &rng) < rules.luckyChance
            let find = MomentRules.finds.randomElement(using: &rng) ?? MomentRules.finds[0]
            let pep = Int.random(in: rules.pep, using: &rng)
            let opens = midnight.addingTimeInterval(TimeInterval(start * 60))
            return PetMoment(
                id: "moment:\(key):\(index)", opens: opens,
                closes: opens.addingTimeInterval(TimeInterval(rules.openFor * 60)),
                find: lucky ? MomentRules.luckyFind : find, pep: lucky ? rules.luckyPep : pep, isLucky: lucky)
        }
    }

    /// The moment open right now, if any.
    public static func open(at date: Date, calendar: Calendar, rules: MomentRules = .v1) -> PetMoment? {
        moments(on: date, calendar: calendar, rules: rules).first { $0.isOpen(at: date) }
    }

    /// Moments opening after `date`, over the next `days` days (for notifications).
    public static func upcoming(
        after date: Date, days: Int = 2, calendar: Calendar, rules: MomentRules = .v1
    ) -> [PetMoment] {
        (0...days).flatMap { offset -> [PetMoment] in
            guard let day = calendar.date(byAdding: .day, value: offset, to: date) else { return [] }
            return moments(on: day, calendar: calendar, rules: rules)
        }
        .filter { $0.opens > date }
    }
}

public extension PepTransaction {
    /// A gift from a pet moment. The moment's id is the transaction id, so it pays once.
    /// Recorded as an adjustment so older app versions can still read the ledger.
    static func momentGift(_ moment: PetMoment, at date: Date) -> PepTransaction {
        PepTransaction(id: moment.id, kind: .adjustment(reason: "Gift: \(moment.find)"), amount: moment.pep, date: date)
    }
}
