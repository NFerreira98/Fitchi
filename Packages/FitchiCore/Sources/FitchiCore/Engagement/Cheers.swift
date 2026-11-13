import Foundation

/// The milestones a pet cheers for as they happen.
public struct CheerRules: Hashable, Sendable {
    public var version: Int
    /// Step counts worth a cheer.
    public var stepMarks: [Int]
    /// Active-minute totals worth a cheer.
    public var minuteMarks: [Int]
    /// The shortest workout that gets its own cheer, in minutes.
    public var workoutMinutes: Double

    public static let v1 = CheerRules(
        version: 1, stepMarks: [5_000, 10_000, 15_000, 20_000], minuteMarks: [30, 60, 90], workoutMinutes: 10)
}

/// Something you did today that your pet cheers for.
public struct Milestone: Hashable, Sendable, Identifiable {
    public enum Kind: Hashable, Sendable {
        case steps(Int)
        case activeMinutes(Int)
        /// A finished workout of `kind`, `minutes` long.
        case workout(ActivityKind, minutes: Int)
        /// Today's Pep reached the daily goal.
        case pepGoal(Int)
    }

    /// Stable, so each device cheers each milestone once (`cheer:2026-11-13:steps-10000`).
    public let id: String
    public let kind: Kind
    /// When it happened (as near as Health can tell), for picking the latest.
    public let happenedAt: Date

    public init(id: String, kind: Kind, happenedAt: Date) {
        self.id = id
        self.kind = kind
        self.happenedAt = happenedAt
    }

    /// Which cheer to play when several land at once: workouts first, then the bigger marks.
    public var weight: Int {
        switch kind {
        case .workout: 4_000_000
        case .pepGoal: 3_000_000
        case .steps(let steps): 1_000_000 + steps
        case .activeMinutes(let minutes): 500_000 + minutes
        }
    }
}

/// Today's milestones, computed from Health data like the rest of the game, so nothing new needs
/// saving or syncing. Each device keeps its own note of which it has already cheered.
public enum Cheers {
    /// Everything reached on the day containing `now`.
    public static func reached(
        at now: Date, samples: [ActivitySample], steps: [StepCount], pepGoal: Int? = nil, pepEarned: Int = 0,
        rules: CheerRules = .v1, calendar: Calendar = .current
    ) -> [Milestone] {
        let day = calendar.startOfDay(for: now)
        let tag = dayTag(day, calendar: calendar)
        var found: [Milestone] = []
        // Steps: where in the day each mark was passed, from the hourly totals.
        var total = 0.0
        var marks = rules.stepMarks.sorted()[...]
        for count in steps.sorted(by: { $0.start < $1.start }) where count.start >= day && count.start <= now {
            total += count.steps
            while let mark = marks.first, total >= Double(mark) {
                found.append(Milestone(id: "cheer:\(tag):steps-\(mark)", kind: .steps(mark), happenedAt: count.end))
                marks.removeFirst()
            }
        }
        // Active minutes: workouts and exercise minutes, overlaps counted once.
        let today = ActivitySample.resolvingOverlaps(
            samples.filter { !$0.isUserEntered && $0.start >= day && $0.end <= now })
        var minutes = 0.0
        var minuteMarks = rules.minuteMarks.sorted()[...]
        for sample in today.sorted(by: { $0.end < $1.end }) {
            minutes += sample.minutes
            while let mark = minuteMarks.first, minutes >= Double(mark) {
                found.append(
                    Milestone(id: "cheer:\(tag):minutes-\(mark)", kind: .activeMinutes(mark), happenedAt: sample.end))
                minuteMarks.removeFirst()
            }
            if sample.kind != .passive, sample.minutes >= rules.workoutMinutes {
                found.append(
                    Milestone(
                        id: "cheer:workout:\(sample.id)",
                        kind: .workout(sample.kind, minutes: Int(sample.minutes.rounded())), happenedAt: sample.end))
            }
        }
        if let pepGoal, pepGoal > 0, pepEarned >= pepGoal {
            found.append(Milestone(id: "cheer:\(tag):pep-goal", kind: .pepGoal(pepGoal), happenedAt: now))
        }
        return found
    }

    /// The one to cheer now from those not yet cheered: the most important, then the latest.
    public static func next(in milestones: [Milestone], cheered: Set<String>) -> Milestone? {
        milestones.filter { !cheered.contains($0.id) }.max { ($0.weight, $0.happenedAt) < ($1.weight, $1.happenedAt) }
    }

    static func dayTag(_ day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
