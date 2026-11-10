import Foundation

/// What the player did on one calendar day: the numbers behind the "Today" screen.
///
/// Only samples that actually earned are counted, so hand-entered and pre-install activity
/// don't show up as minutes that "should" have paid out.
public struct DailySummary: Hashable, Sendable {
    public var day: Date
    public var activeMinutes: Int
    public var workoutCount: Int
    public var pepEarned: Int

    public init(day: Date, activeMinutes: Int, workoutCount: Int, pepEarned: Int) {
        self.day = day
        self.activeMinutes = activeMinutes
        self.workoutCount = workoutCount
        self.pepEarned = pepEarned
    }

    /// Summarises the day containing `date`. `earnings` should come from
    /// `PointsRules.earnings(for:since:calendar:)` over the same `samples`.
    public init(containing date: Date, samples: [ActivitySample], earnings: [Earning], calendar: Calendar) {
        let day = calendar.startOfDay(for: date)
        let todays = earnings.filter { $0.day == day }
        let earnedIDs = Set(todays.map(\.sourceID))
        var counted: [String: ActivitySample] = [:]
        for sample in samples where earnedIDs.contains(sample.id) {
            counted[sample.id] = counted[sample.id] ?? sample
        }
        self.init(
            day: day,
            activeMinutes: Int(counted.values.reduce(0) { $0 + $1.minutes }.rounded()),
            workoutCount: counted.values.count { $0.kind != .passive },
            pepEarned: todays.reduce(0) { $0 + $1.amount }
        )
    }
}
