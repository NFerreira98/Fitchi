import Foundation

public enum ComebackError: Error, Equatable {
    case petHasNotRunAway
    case questIncomplete(minutesDone: Double, minutesNeeded: Double)
}

/// The comeback quest: a pet that ran away returns once the player logs enough activity.
/// Pets are never lost permanently. Coming back to exercise *is* the way to get them back.
public struct ComebackQuest: Hashable, Sendable {
    public var requiredMinutes: Double
    /// Stats the pet returns home with.
    public var returnValue: Double

    public static let v1 = ComebackQuest(requiredMinutes: 60, returnValue: 50)

    /// Active minutes (hand-entered samples excluded) logged since the pet ran away.
    public func progress(for pet: Pet, samples: [ActivitySample], at date: Date, in context: DecayContext) -> Double? {
        guard let leftAt = pet.ranAwayDate(at: date, in: context) else { return nil }
        var seen = Set<String>()
        return samples
            .filter { !$0.isUserEntered && $0.start >= leftAt && $0.start <= date && seen.insert($0.id).inserted }
            .reduce(0) { $0 + $1.minutes }
    }

    /// Brings the pet home if the quest is complete.
    public func bringHome(
        _ pet: inout Pet,
        samples: [ActivitySample],
        at date: Date,
        in context: DecayContext
    ) throws(ComebackError) {
        guard let done = progress(for: pet, samples: samples, at: date, in: context) else {
            throw .petHasNotRunAway
        }
        guard done >= requiredMinutes else {
            throw .questIncomplete(minutesDone: done, minutesNeeded: requiredMinutes)
        }
        for stat in Stat.allCases {
            pet.setStat(stat, to: returnValue, at: date)
        }
    }
}
