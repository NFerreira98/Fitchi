import Foundation

/// A snapshot of lifetime progress that achievements are evaluated against.
public struct PlayerProgress: Hashable, Sendable {
    public var activeMinutes: Double
    public var workoutCounts: [ActivityKind: Int]
    public var longestStreakDays: Int
    public var currentStreakDays: Int
    public var petsOwned: Int
    public var pepEarned: Int
    public var itemsPurchased: Int

    public init(
        activeMinutes: Double = 0,
        workoutCounts: [ActivityKind: Int] = [:],
        longestStreakDays: Int = 0,
        currentStreakDays: Int = 0,
        petsOwned: Int = 0,
        pepEarned: Int = 0,
        itemsPurchased: Int = 0
    ) {
        self.activeMinutes = activeMinutes
        self.workoutCounts = workoutCounts
        self.longestStreakDays = longestStreakDays
        self.currentStreakDays = currentStreakDays
        self.petsOwned = petsOwned
        self.pepEarned = pepEarned
        self.itemsPurchased = itemsPurchased
    }

    public func workoutCount(kind: ActivityKind?) -> Int {
        guard let kind else { return workoutCounts.values.reduce(0, +) }
        return workoutCounts[kind, default: 0]
    }

    /// Builds progress from raw history. A streak day is a day with at least
    /// `streakMinimumMinutes` of eligible activity.
    public static func compute(
        samples: [ActivitySample],
        since installDate: Date,
        wallet: Wallet,
        petsOwned: Int,
        at date: Date,
        calendar: Calendar,
        streakMinimumMinutes: Double = 20
    ) -> PlayerProgress {
        var seen = Set<String>()
        let eligible = samples.filter {
            !$0.isUserEntered && $0.start >= installDate && $0.start <= date && seen.insert($0.id).inserted
        }

        var workoutCounts: [ActivityKind: Int] = [:]
        var minutesByDay: [Date: Double] = [:]
        for sample in eligible {
            if sample.kind != .passive { workoutCounts[sample.kind, default: 0] += 1 }
            minutesByDay[calendar.startOfDay(for: sample.start), default: 0] += sample.minutes
        }
        let streakDays = Set(minutesByDay.filter { $0.value >= streakMinimumMinutes }.keys)
        let purchases = wallet.transactions.filter {
            if case .purchase = $0.kind { return true }
            return false
        }

        return PlayerProgress(
            activeMinutes: eligible.reduce(0) { $0 + $1.minutes },
            workoutCounts: workoutCounts,
            longestStreakDays: longestRun(of: streakDays, calendar: calendar),
            currentStreakDays: currentRun(of: streakDays, at: date, calendar: calendar),
            petsOwned: petsOwned,
            pepEarned: wallet.totalEarned,
            itemsPurchased: purchases.count
        )
    }

    private static func longestRun(of days: Set<Date>, calendar: Calendar) -> Int {
        var longest = 0
        for day in days {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day), !days.contains(previous) else {
                continue
            }
            var length = 1
            var cursor = day
            while let next = calendar.date(byAdding: .day, value: 1, to: cursor), days.contains(next) {
                length += 1
                cursor = next
            }
            longest = max(longest, length)
        }
        return longest
    }

    /// Streak ending today, or ending yesterday (today isn't over yet).
    private static func currentRun(of days: Set<Date>, at date: Date, calendar: Calendar) -> Int {
        var cursor = calendar.startOfDay(for: date)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor), days.contains(yesterday) else {
                return 0
            }
            cursor = yesterday
        }
        var length = 0
        while days.contains(cursor) {
            length += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return length
    }
}
