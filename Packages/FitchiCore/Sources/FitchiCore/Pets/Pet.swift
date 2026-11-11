import Foundation

/// Equipment slots for wearable accessories.
public enum AccessorySlot: String, Codable, CaseIterable, Sendable, CodingKeyRepresentable {
    case head
    case face
    case neck
    case back
}

/// One individual pet the player owns.
///
/// Stats are stored as anchors (value + date of last change). Current values, mood and neglect
/// stage are always *computed* for a given date, never stored.
public struct Pet: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public let speciesID: String
    public let traits: PetTraits
    public let personality: Personality
    public let hatchedAt: Date
    /// The colouring rolled at hatch; nil for pets hatched before variants existed.
    public let variant: PetVariant?
    /// The active pet lives on the watch and decays at full speed; others rest at home.
    public private(set) var isActive: Bool
    public private(set) var stats: [Stat: StatAnchor]
    public var equipped: [AccessorySlot: String]

    public init(
        id: UUID = UUID(),
        name: String,
        speciesID: String,
        traits: PetTraits,
        personality: Personality,
        hatchedAt: Date,
        variant: PetVariant? = nil,
        isActive: Bool = false,
        initialValue: Double = 80
    ) {
        self.id = id
        self.name = name
        self.speciesID = speciesID
        self.traits = traits
        self.personality = personality
        self.hatchedAt = hatchedAt
        self.variant = variant
        self.isActive = isActive
        self.stats = Dictionary(
            uniqueKeysWithValues: Stat.allCases.map { ($0, StatAnchor(value: initialValue, date: hatchedAt)) })
        self.equipped = [:]
    }

    // MARK: - Computed state

    public var isShiny: Bool { variant?.isShiny ?? false }

    public func anchor(for stat: Stat) -> StatAnchor {
        stats[stat] ?? StatAnchor(value: Stat.range.upperBound, date: hatchedAt)
    }

    /// Most recent moment any stat was changed.
    public var lastCareDate: Date {
        stats.values.map(\.date).max() ?? hatchedAt
    }

    public func decayRate(for stat: Stat, config: DecayConfig) -> Double {
        let base = config.basePerHour[stat] ?? 0
        let resting = isActive ? 1 : config.restingFactor
        return base * traits.decayMultiplier(for: stat) * personality.decayMultiplier(for: stat) * resting
    }

    public func value(of stat: Stat, at date: Date, in context: DecayContext) -> Double {
        let anchor = anchor(for: stat)
        guard date > anchor.date else { return anchor.value }
        let hours = context.effectiveHours(from: anchor.date, to: date)
        return (anchor.value - decayRate(for: stat, config: context.config) * hours).clamped(to: Stat.range)
    }

    public func values(at date: Date, in context: DecayContext) -> [Stat: Double] {
        Dictionary(uniqueKeysWithValues: Stat.allCases.map { ($0, value(of: $0, at: date, in: context)) })
    }

    /// Average of all four stats.
    public func wellbeing(at date: Date, in context: DecayContext) -> Double {
        Stat.allCases.reduce(0) { $0 + value(of: $1, at: date, in: context) } / Double(Stat.allCases.count)
    }

    /// When the current neglect spell began (wellbeing fell to the neglect threshold), or nil if
    /// the pet is not neglected at `date`.
    public func neglectStart(at date: Date, in context: DecayContext) -> Date? {
        let threshold = context.config.neglectThreshold
        let lastCare = lastCareDate
        guard date >= lastCare, wellbeing(at: date, in: context) <= threshold else { return nil }
        if wellbeing(at: lastCare, in: context) <= threshold { return lastCare }
        // Wellbeing only declines after the last care event, so binary-search the crossing.
        var low = lastCare
        var high = date
        while high.timeIntervalSince(low) > 1 {
            let mid = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
            if wellbeing(at: mid, in: context) <= threshold { high = mid } else { low = mid }
        }
        return high
    }

    /// When the pet ran away, if it has.
    public func ranAwayDate(at date: Date, in context: DecayContext) -> Date? {
        guard let start = neglectStart(at: date, in: context) else { return nil }
        let leaveDate = context.date(addingActiveTime: context.config.runAwayAfter, to: start)
        return leaveDate <= date ? leaveDate : nil
    }

    public func condition(at date: Date, in context: DecayContext) -> PetCondition {
        let config = context.config
        if let start = neglectStart(at: date, in: context) {
            func reached(_ offset: TimeInterval) -> Bool {
                context.date(addingActiveTime: offset, to: start) <= date
            }
            if reached(config.runAwayAfter) { return .ranAway }
            if reached(config.packingAfter) { return .packing }
            if reached(config.sickAfter) { return .sick }
            return .sad
        }
        let wellbeing = wellbeing(at: date, in: context)
        if wellbeing >= config.thrivingThreshold { return .thriving }
        if wellbeing >= config.contentThreshold { return .content }
        return .sad
    }

    // MARK: - Mutations (validated by Care / PetRoster)

    /// Sets a stat to `value` as of `date`.
    mutating func setStat(_ stat: Stat, to value: Double, at date: Date) {
        stats[stat] = StatAnchor(value: value.clamped(to: Stat.range), date: date)
    }

    /// Freezes every stat at its current value, so later decay uses the new rate.
    mutating func reanchor(at date: Date, in context: DecayContext) {
        for stat in Stat.allCases {
            setStat(stat, to: value(of: stat, at: date, in: context), at: date)
        }
    }

    mutating func setActive(_ active: Bool, at date: Date, in context: DecayContext) {
        guard active != isActive else { return }
        reanchor(at: date, in: context)
        isActive = active
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
