import Foundation

/// A goal with a Pep reward. Loaded from `Content/achievements.json`.
public struct Achievement: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var description: String
    public var reward: Int
    public var criterion: Criterion

    public init(id: String, name: String, description: String, reward: Int, criterion: Criterion) {
        self.id = id
        self.name = name
        self.description = description
        self.reward = reward
        self.criterion = criterion
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

    public func isMet(by progress: PlayerProgress) -> Bool {
        switch self {
        case .activeMinutes(let minutes): progress.activeMinutes >= minutes
        case .workouts(let kind, let count): progress.workoutCount(kind: kind) >= count
        case .streakDays(let days): progress.longestStreakDays >= days
        case .petsOwned(let count): progress.petsOwned >= count
        case .pepEarned(let amount): progress.pepEarned >= amount
        case .itemsPurchased(let count): progress.itemsPurchased >= count
        }
    }
}

extension Criterion: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, minutes, kind, count, days, amount
    }

    private enum Tag: String, Codable {
        case activeMinutes, workouts, streakDays, petsOwned, pepEarned, itemsPurchased
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
        }
    }
}
