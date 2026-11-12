import Foundation

/// A goal with a Pep reward. Loaded from `Content/achievements.json`.
public struct Achievement: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var description: String
    public var reward: Int
    public var criterion: Criterion
    /// An SF Symbol name for the badge (data, so new achievements need no code).
    public var icon: String?

    public init(
        id: String, name: String, description: String, reward: Int, criterion: Criterion, icon: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.reward = reward
        self.criterion = criterion
        self.icon = icon
    }

    public func isUnlocked(by progress: PlayerProgress) -> Bool {
        criterion.isMet(by: progress)
    }

    /// Achievements in `all` newly unlocked by `progress` that weren't already unlocked.
    public static func newlyUnlocked(
        _ all: [Achievement],
        progress: PlayerProgress,
        alreadyUnlocked: Set<String>
    ) -> [Achievement] {
        all.filter { !alreadyUnlocked.contains($0.id) && $0.isUnlocked(by: progress) }
    }
}

/// What must be true to unlock an achievement.
///
/// JSON form: `{"type": "streakDays", "days": 7}`, `{"type": "workouts", "kind": "run", "count": 10}`.
public enum Criterion: Hashable, Sendable {
    case activeMinutes(Double)
    /// `kind == nil` counts workouts of any kind.
    case workouts(kind: ActivityKind?, count: Int)
    case streakDays(Int)
    case petsOwned(Int)
    case pepEarned(Int)
    case itemsPurchased(Int)
    /// Lifetime steps since install.
    case steps(Int)
    /// Collection entries (species × colouring, shinies included) found.
    case collectionFound(Int)
    case shiniesFound(Int)
    /// Different species found.
    case speciesFound(Int)
    /// Found a species of this rarity or rarer.
    case rarityFound(Rarity)
    /// Days since the first pet hatched.
    case daysTogether(Int)
    /// Backdrops bought (the free meadow doesn't count).
    case backdropsOwned(Int)

    public func isMet(by progress: PlayerProgress) -> Bool {
        let (current, target) = self.progress(in: progress)
        return current >= target
    }

    /// How far along the player is, for progress bars: (current, target).
    public func progress(in progress: PlayerProgress) -> (current: Double, target: Double) {
        switch self {
        case .activeMinutes(let minutes): (progress.activeMinutes, minutes)
        case .workouts(let kind, let count): (Double(progress.workoutCount(kind: kind)), Double(count))
        case .streakDays(let days): (Double(progress.longestStreakDays), Double(days))
        case .petsOwned(let count): (Double(progress.petsOwned), Double(count))
        case .pepEarned(let amount): (Double(progress.pepEarned), Double(amount))
        case .itemsPurchased(let count): (Double(progress.itemsPurchased), Double(count))
        case .steps(let count): (Double(progress.stepsTaken), Double(count))
        case .collectionFound(let count): (Double(progress.collectionFound), Double(count))
        case .shiniesFound(let count): (Double(progress.shiniesFound), Double(count))
        case .speciesFound(let count): (Double(progress.speciesFound), Double(count))
        case .rarityFound(let rarity): (progress.rarestFound.map { $0 >= rarity ? 1 : 0 } ?? 0, 1)
        case .daysTogether(let days): (Double(progress.daysTogether), Double(days))
        case .backdropsOwned(let count): (Double(progress.backdropsOwned), Double(count))
        }
    }
}

extension Criterion: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, minutes, kind, count, days, amount, rarity
    }

    private enum Tag: String, Codable {
        case activeMinutes, workouts, streakDays, petsOwned, pepEarned, itemsPurchased
        case steps, collectionFound, shiniesFound, speciesFound, rarityFound, daysTogether, backdropsOwned
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Tag.self, forKey: .type) {
        case .activeMinutes: self = .activeMinutes(try container.decode(Double.self, forKey: .minutes))
        case .workouts:
            self = .workouts(
                kind: try container.decodeIfPresent(ActivityKind.self, forKey: .kind),
                count: try container.decode(Int.self, forKey: .count)
            )
        case .streakDays: self = .streakDays(try container.decode(Int.self, forKey: .days))
        case .petsOwned: self = .petsOwned(try container.decode(Int.self, forKey: .count))
        case .pepEarned: self = .pepEarned(try container.decode(Int.self, forKey: .amount))
        case .itemsPurchased: self = .itemsPurchased(try container.decode(Int.self, forKey: .count))
        case .steps: self = .steps(try container.decode(Int.self, forKey: .count))
        case .collectionFound: self = .collectionFound(try container.decode(Int.self, forKey: .count))
        case .shiniesFound: self = .shiniesFound(try container.decode(Int.self, forKey: .count))
        case .speciesFound: self = .speciesFound(try container.decode(Int.self, forKey: .count))
        case .rarityFound: self = .rarityFound(try container.decode(Rarity.self, forKey: .rarity))
        case .daysTogether: self = .daysTogether(try container.decode(Int.self, forKey: .days))
        case .backdropsOwned: self = .backdropsOwned(try container.decode(Int.self, forKey: .count))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .activeMinutes(let minutes):
            try container.encode(Tag.activeMinutes, forKey: .type)
            try container.encode(minutes, forKey: .minutes)
        case .workouts(let kind, let count):
            try container.encode(Tag.workouts, forKey: .type)
            try container.encodeIfPresent(kind, forKey: .kind)
            try container.encode(count, forKey: .count)
        case .streakDays(let days):
            try container.encode(Tag.streakDays, forKey: .type)
            try container.encode(days, forKey: .days)
        case .petsOwned(let count):
            try container.encode(Tag.petsOwned, forKey: .type)
            try container.encode(count, forKey: .count)
        case .pepEarned(let amount):
            try container.encode(Tag.pepEarned, forKey: .type)
            try container.encode(amount, forKey: .amount)
        case .itemsPurchased(let count):
            try container.encode(Tag.itemsPurchased, forKey: .type)
            try container.encode(count, forKey: .count)
        case .steps(let count): try encode(.steps, count: count, into: &container)
        case .collectionFound(let count): try encode(.collectionFound, count: count, into: &container)
        case .shiniesFound(let count): try encode(.shiniesFound, count: count, into: &container)
        case .speciesFound(let count): try encode(.speciesFound, count: count, into: &container)
        case .backdropsOwned(let count): try encode(.backdropsOwned, count: count, into: &container)
        case .rarityFound(let rarity):
            try container.encode(Tag.rarityFound, forKey: .type)
            try container.encode(rarity, forKey: .rarity)
        case .daysTogether(let days):
            try container.encode(Tag.daysTogether, forKey: .type)
            try container.encode(days, forKey: .days)
        }
    }

    private func encode(_ tag: Tag, count: Int, into container: inout KeyedEncodingContainer<CodingKeys>) throws {
        try container.encode(tag, forKey: .type)
        try container.encode(count, forKey: .count)
    }
}
