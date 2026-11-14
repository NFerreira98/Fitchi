import Foundation

/// A heads-up that the pet is about to reach a worse stage of neglect: feeling sick, packing
/// its bags (the last warning) or running away.
public struct NeglectWarning: Hashable, Sendable {
    public var date: Date
    /// `.sick`, `.packing` or `.ranAway`.
    public var condition: PetCondition

    public init(date: Date, condition: PetCondition) {
        self.date = date
        self.condition = condition
    }
}

/// Plans neglect warnings from the decay model, like `CareNudges`: if nobody looks after the
/// pet, the moment each stage begins is known in advance, so they can be scheduled as local
/// notifications. Any care pushes the stages back, so callers re-plan after every change.
public enum NeglectWarnings {
    /// How far ahead to look for neglect beginning (a full pet takes a few days to get there).
    public static let horizon: TimeInterval = 30 * .day

    public static func plan(for pet: Pet, after now: Date, in context: DecayContext) -> [NeglectWarning] {
        guard pet.isActive,
            let start = pet.neglectStart(at: now, in: context) ?? pet.neglectBegins(after: now, in: context)
        else { return [] }
        let config = context.config
        let stages: [(PetCondition, TimeInterval)] = [
            (.sick, config.sickAfter), (.packing, config.packingAfter), (.ranAway, config.runAwayAfter),
        ]
        return stages.compactMap { condition, offset in
            // A minute in, so the pet is sure to show it when the player looks (the searches
            // behind both are exact to a second).
            let date = context.date(addingActiveTime: offset, to: start).addingTimeInterval(60)
            guard date > now else { return nil }
            // Nobody wants bad news at 3 a.m.; it waits for the morning like the care nudges.
            return NeglectWarning(date: CareNudges.outsideQuietHours(date, in: context), condition: condition)
        }
    }
}

extension Pet {
    /// When wellbeing will first fall to the neglect line after `now` without care, or nil if
    /// it already has or won't within `NeglectWarnings.horizon`. Wellbeing only falls between
    /// care events, so a binary search is exact to a second.
    func neglectBegins(after now: Date, in context: DecayContext) -> Date? {
        let threshold = context.config.neglectThreshold
        guard wellbeing(at: now, in: context) > threshold else { return nil }
        var high = now.addingTimeInterval(NeglectWarnings.horizon)
        guard wellbeing(at: high, in: context) <= threshold else { return nil }
        var low = now
        while high.timeIntervalSince(low) > 1 {
            let mid = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
            if wellbeing(at: mid, in: context) <= threshold { high = mid } else { low = mid }
        }
        return high
    }
}
