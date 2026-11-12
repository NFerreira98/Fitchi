import Foundation

/// A reminder that the pet will need something: the moment one or more stats fall to the
/// "needs you" line (`PetMood.needThreshold`), when the pet starts showing it.
public struct CareNudge: Hashable, Sendable {
    public var date: Date
    /// Needs that come due together, most urgent first.
    public var stats: [Stat]

    public init(date: Date, stats: [Stat]) {
        self.date = date
        self.stats = stats
    }
}

/// Plans care reminders from the decay model. Stats are computed from timestamps, so the
/// moment each one gets low is known in advance and can be scheduled as a local notification;
/// any care changes the plan, so callers re-plan after every change.
public enum CareNudges {
    /// Needs due within this window of each other become one reminder.
    public static let groupingWindow: TimeInterval = 45 * 60
    /// How far ahead to plan.
    public static let horizon: TimeInterval = 3 * .day

    public static func plan(for pet: Pet, after now: Date, in context: DecayContext) -> [CareNudge] {
        guard pet.isActive, pet.condition(at: now, in: context) != .ranAway else { return [] }
        let due = Stat.allCases.compactMap { stat -> (stat: Stat, date: Date)? in
            guard
                let date = pet.date(
                    when: stat, fallsTo: PetMood.needThreshold, after: now, within: horizon, in: context)
            else { return nil }
            return (stat, outsideQuietHours(date, in: context))
        }
        .sorted { ($0.date, $0.stat.rawValue) < ($1.date, $1.stat.rawValue) }

        var nudges: [CareNudge] = []
        for (stat, date) in due {
            if let last = nudges.last, date.timeIntervalSince(last.date) <= groupingWindow {
                nudges[nudges.count - 1].stats.append(stat)
            } else {
                nudges.append(CareNudge(date: date, stats: [stat]))
            }
        }
        return nudges
    }

    /// Night reminders wait for the morning: the pet is asleep, and so is the player.
    static func outsideQuietHours(_ date: Date, in context: DecayContext) -> Date {
        guard context.isNight(date) else { return date }
        let calendar = context.calendar
        let morning = DateComponents(hour: context.config.nightEndHour, minute: 0, second: 0)
        return calendar.nextDate(after: date, matching: morning, matchingPolicy: .nextTime) ?? date
    }
}

public extension Pet {
    /// When `stat` first falls to `threshold` after `now`, or nil if it already has or won't
    /// within `horizon`. Stats only fall between care events, so a binary search is exact to a
    /// second regardless of night slowdown and vacations.
    func date(
        when stat: Stat, fallsTo threshold: Double, after now: Date, within horizon: TimeInterval,
        in context: DecayContext
    ) -> Date? {
        guard value(of: stat, at: now, in: context) > threshold else { return nil }
        var high = now.addingTimeInterval(horizon)
        guard value(of: stat, at: high, in: context) <= threshold else { return nil }
        var low = now
        while high.timeIntervalSince(low) > 1 {
            let mid = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
            if value(of: stat, at: mid, in: context) <= threshold { high = mid } else { low = mid }
        }
        return high
    }
}
