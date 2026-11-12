import Foundation

/// What a pet looks like it feels right now, so players can read its needs without the stat
/// rings. Derived from stats, condition and the time of day; never stored.
public struct PetMood: Hashable, Sendable {
    public var condition: PetCondition
    public var isHungry: Bool
    public var isBored: Bool
    public var isTired: Bool
    public var isDirty: Bool
    /// Sleeping through the night, or too exhausted to stay awake.
    public var isAsleep: Bool

    public init(
        condition: PetCondition = .content, isHungry: Bool = false, isBored: Bool = false, isTired: Bool = false,
        isDirty: Bool = false, isAsleep: Bool = false
    ) {
        self.condition = condition
        self.isHungry = isHungry
        self.isBored = isBored
        self.isTired = isTired
        self.isDirty = isDirty
        self.isAsleep = isAsleep
    }

    /// A stat at or below this shows on the pet (a thought bubble, droopy eyes, stink lines).
    public static let needThreshold: Double = 35
    /// Below this much energy the pet dozes off even in the daytime.
    public static let exhaustedThreshold: Double = 10

    public static let content = PetMood()

    public init(values: [Stat: Double], condition: PetCondition, isNight: Bool) {
        func low(_ stat: Stat) -> Bool { values[stat, default: 100] <= Self.needThreshold }
        let energy = values[.energy, default: 100]
        self.init(
            condition: condition,
            isHungry: low(.hunger),
            isBored: low(.happiness),
            isTired: low(.energy),
            isDirty: low(.cleanliness),
            isAsleep: condition != .ranAway && (isNight || energy <= Self.exhaustedThreshold)
        )
    }

    public var isThriving: Bool { condition == .thriving }
    /// Sad, sick or about to leave: the pet droops and frowns.
    public var isDown: Bool { [.sad, .sick, .packing].contains(condition) }
}

public extension Pet {
    func mood(at date: Date, in context: DecayContext) -> PetMood {
        PetMood(
            values: values(at: date, in: context),
            condition: condition(at: date, in: context),
            isNight: context.isNight(date)
        )
    }
}
