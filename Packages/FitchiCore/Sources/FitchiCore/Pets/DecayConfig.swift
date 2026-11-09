import Foundation

/// Tunable numbers for how pets' needs decline and how neglect escalates.
/// Changing semantics here should bump `FitchiCore.rulesVersion`.
public struct DecayConfig: Hashable, Sendable {
    /// Points lost per *effective* hour for an average pet (traits and personality scale this).
    public var basePerHour: [Stat: Double]
    /// Local-time window when decay slows down so players don't wake up to a starving pet.
    public var nightStartHour: Int
    public var nightEndHour: Int
    public var nightFactor: Double
    /// Decay multiplier for pets that are not the active (on-watch) pet.
    public var restingFactor: Double

    /// Mood thresholds on average wellbeing.
    public var thrivingThreshold: Double
    public var contentThreshold: Double

    /// Neglect begins when average wellbeing drops to this value or below.
    public var neglectThreshold: Double
    /// Time spent neglected (vacation excluded) before each stage begins.
    public var sickAfter: TimeInterval
    public var packingAfter: TimeInterval
    public var runAwayAfter: TimeInterval
    /// Care items are less effective while the pet is sick.
    public var sickCareMultiplier: Double

    public static let v1 = DecayConfig(
        basePerHour: [.hunger: 2.1, .happiness: 1.7, .energy: 1.5, .cleanliness: 1.2],
        nightStartHour: 22,
        nightEndHour: 7,
        nightFactor: 0.3,
        restingFactor: 0.25,
        thrivingThreshold: 70,
        contentThreshold: 40,
        neglectThreshold: 15,
        sickAfter: 2 * .day,
        packingAfter: 4 * .day,
        runAwayAfter: 6 * .day,
        sickCareMultiplier: 0.5
    )
}

/// Everything time-related a decay calculation needs: the rules, the player's calendar
/// (for night hours) and any vacation periods during which decay is frozen.
public struct DecayContext: Sendable {
    public var config: DecayConfig
    public var calendar: Calendar
    public var vacations: [DateInterval]

    public init(config: DecayConfig = .v1, calendar: Calendar = .current, vacations: [DateInterval] = []) {
        self.config = config
        self.calendar = calendar
        self.vacations = vacations.sorted { $0.start < $1.start }
    }

    /// Hours between `start` and `end`, with night hours weighted by `nightFactor` and
    /// vacation hours excluded entirely.
    public func effectiveHours(from start: Date, to end: Date) -> Double {
        guard end > start else { return 0 }
        let cuts = segmentBoundaries(from: start, to: end)
        var total = 0.0
        for (segmentStart, segmentEnd) in zip(cuts, cuts.dropFirst()) {
            let seconds = segmentEnd.timeIntervalSince(segmentStart)
            let midpoint = segmentStart.addingTimeInterval(seconds / 2)
            if isOnVacation(midpoint) { continue }
            total += seconds / 3_600 * (isNight(midpoint) ? config.nightFactor : 1)
        }
        return total
    }

    /// The date reached after `seconds` of non-vacation time have elapsed since `start`.
    public func date(addingActiveTime seconds: TimeInterval, to start: Date) -> Date {
        var cursor = start
        var remaining = seconds
        for vacation in vacations where vacation.end > cursor {
            let gap = max(0, vacation.start.timeIntervalSince(cursor))
            if remaining <= gap { return cursor.addingTimeInterval(remaining) }
            remaining -= gap
            cursor = max(cursor, vacation.end)
        }
        return cursor.addingTimeInterval(remaining)
    }

    public func isNight(_ date: Date) -> Bool {
        let hour = calendar.component(.hour, from: date)
        if config.nightStartHour > config.nightEndHour {
            return hour >= config.nightStartHour || hour < config.nightEndHour
        }
        return hour >= config.nightStartHour && hour < config.nightEndHour
    }

    public func isOnVacation(_ date: Date) -> Bool {
        vacations.contains { $0.contains(date) }
    }

    private func segmentBoundaries(from start: Date, to end: Date) -> [Date] {
        var cuts: Set<Date> = [start, end]
        var day = calendar.startOfDay(for: start)
        while day <= end {
            for hour in [config.nightStartHour, config.nightEndHour] {
                if let boundary = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day),
                    boundary > start, boundary < end
                {
                    cuts.insert(boundary)
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        for vacation in vacations {
            for edge in [vacation.start, vacation.end] where edge > start && edge < end {
                cuts.insert(edge)
            }
        }
        return cuts.sorted()
    }
}

extension TimeInterval {
    public static let hour: TimeInterval = 3_600
    public static let day: TimeInterval = 86_400
}
