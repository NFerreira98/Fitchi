import Foundation

public enum ComebackError: Error, Equatable {
    case petHasNotRunAway
    case questIncomplete(minutesDone: Double, minutesNeeded: Double)
}

/// How far the player is with bringing a pet home.
public struct ComebackProgress: Hashable, Sendable {
    /// When the pet ran away. Only activity after this counts.
    public var leftAt: Date
    /// Workout and exercise minutes since then, plus everyday steps converted to minutes.
    public var activeMinutes: Double
    public var requiredMinutes: Double
    /// Everyday steps worth one active minute.
    public var stepsPerMinute: Double

    public init(leftAt: Date, activeMinutes: Double, requiredMinutes: Double, stepsPerMinute: Double) {
        self.leftAt = leftAt
        self.activeMinutes = activeMinutes
        self.requiredMinutes = requiredMinutes
        self.stepsPerMinute = stepsPerMinute
    }

    public var isComplete: Bool { activeMinutes >= requiredMinutes }
    public var fraction: Double { min(1, activeMinutes / max(1, requiredMinutes)) }
    public var minutesRemaining: Int { Int(max(0, requiredMinutes - activeMinutes).rounded(.up)) }
    /// The same distance in everyday steps, rounded up to hundreds.
    public var stepsRemaining: Int {
        Int((max(0, requiredMinutes - activeMinutes) * stepsPerMinute / 100).rounded(.up)) * 100
    }
}

/// The comeback quest: a pet that ran away returns once the player logs enough activity.
/// Pets are never lost permanently. Coming back to exercise *is* the way to get them back.
/// Everyday steps count too (like hatching the egg), so players without a watch can do it.
public struct ComebackQuest: Hashable, Sendable {
    public var requiredMinutes: Double
    /// Stats the pet returns home with.
    public var returnValue: Double
    /// Everyday steps (outside workouts and exercise minutes) worth one active minute.
    public var stepsPerMinute: Double

    public static let v1 = ComebackQuest(requiredMinutes: 60, returnValue: 50, stepsPerMinute: 100)

    /// Progress since the pet ran away, or nil if it hasn't. Hand-entered samples don't count;
    /// samples must have overlaps resolved, as `HealthDataSource` returns them.
    public func progress(
        for pet: Pet, samples: [ActivitySample], steps: [StepCount] = [], at date: Date, in context: DecayContext
    ) -> ComebackProgress? {
        guard let leftAt = pet.ranAwayDate(at: date, in: context) else { return nil }
        var seen = Set<String>()
        let exercise =
            samples
            .filter { !$0.isUserEntered && $0.end > leftAt && $0.start <= date && seen.insert($0.id).inserted }
            .reduce(0) { $0 + $1.end.timeIntervalSince(max($1.start, leftAt)) / 60 }
        let walking =
            stepsPerMinute > 0 ? steps.everydaySteps(after: leftAt, excluding: samples) / stepsPerMinute : 0
        return ComebackProgress(
            leftAt: leftAt, activeMinutes: exercise + walking, requiredMinutes: requiredMinutes,
            stepsPerMinute: stepsPerMinute)
    }

    /// Brings the pet home if the quest is complete: every need set to `returnValue`.
    public func bringHome(
        _ pet: inout Pet,
        samples: [ActivitySample],
        steps: [StepCount] = [],
        at date: Date,
        in context: DecayContext
    ) throws(ComebackError) {
        guard let progress = progress(for: pet, samples: samples, steps: steps, at: date, in: context) else {
            throw .petHasNotRunAway
        }
        guard progress.isComplete else {
            throw .questIncomplete(minutesDone: progress.activeMinutes, minutesNeeded: requiredMinutes)
        }
        for stat in Stat.allCases {
            pet.setStat(stat, to: returnValue, at: date)
        }
    }
}

public extension Pet {
    /// This pet as if nobody had looked after it for long enough to have run away by `date`.
    /// For previews and developer tools; real pets run away on their own.
    func leftAlone(until date: Date, in context: DecayContext) -> Pet {
        var pet = self
        let since = date.addingTimeInterval(-(context.config.runAwayAfter + .day))
        for stat in Stat.allCases { pet.setStat(stat, to: 0, at: since) }
        return pet
    }
}
