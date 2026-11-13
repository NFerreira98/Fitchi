import Foundation

/// What a daily quest asks for.
public enum QuestGoal: Hashable, Sendable {
    /// At least `steps` steps before `hour`:00.
    case stepsBefore(steps: Int, hour: Int)
    /// At least `steps` steps from `hour`:00 on.
    case stepsAfter(steps: Int, hour: Int)
    case steps(Int)
    /// Active minutes (workouts and exercise minutes), optionally only before `hour`:00.
    case activeMinutes(Int, before: Int?)
    case workout
    case care(CareAction)
    /// Collect this many gifts from pet moments.
    case gifts(Int)

    /// Kind of goal, for ids: "steps-before-12".
    var slug: String {
        switch self {
        case .stepsBefore(let steps, let hour): "steps-before-\(hour)-\(steps)"
        case .stepsAfter(let steps, let hour): "steps-after-\(hour)-\(steps)"
        case .steps(let steps): "steps-\(steps)"
        case .activeMinutes(let minutes, let hour): "minutes-\(minutes)" + (hour.map { "-before-\($0)" } ?? "")
        case .workout: "workout"
        case .care(let action): "care-\(action.rawValue)"
        case .gifts(let count): "gifts-\(count)"
        }
    }
}

/// Something to celebrate from the day's quests.
public enum QuestNotice: Hashable, Sendable, Identifiable {
    case quest(Quest)
    /// All three done: the streak ladder's reward for this day.
    case allDone(reward: StreakReward, streak: Int)

    public var id: String {
        switch self {
        case .quest(let quest): quest.id
        case .allDone(_, let streak): "all-done:\(streak)"
        }
    }
}

/// What one rung of the streak ladder pays.
public enum StreakReward: Hashable, Sendable {
    case pep(Int)
    /// A free egg of this `EggType` id, hatched on the iPhone.
    case egg(String)
}

/// Generous, escalating rewards for finishing every quest day after day: a week of growing Pep
/// rewards ending in a free egg, with a bigger egg every few weeks. A missed day pauses the
/// climb (one is forgiven); two in a row start it over.
public struct StreakLadder: Hashable, Sendable {
    /// Pep for days 1…n of each week; the day after the last is the egg.
    public var pep: [Int]
    public var egg: String
    /// Every this-many weeks, the week ends with `bigEgg` instead.
    public var bigEggEvery: Int
    public var bigEgg: String

    public init(pep: [Int], egg: String, bigEggEvery: Int, bigEgg: String) {
        self.pep = pep
        self.egg = egg
        self.bigEggEvery = bigEggEvery
        self.bigEgg = bigEgg
    }

    public static let v1 = StreakLadder(
        pep: [15, 20, 25, 35, 45, 60], egg: "sparkle-egg", bigEggEvery: 4, bigEgg: "golden-egg")

    /// Days in one turn of the ladder.
    public var length: Int { pep.count + 1 }

    /// The reward for the `day`th day of a streak (1-based).
    public func reward(forDay day: Int) -> StreakReward {
        rungs(forWeek: week(ofDay: day))[(max(day, 1) - 1) % length]
    }

    /// Which turn of the ladder (1-based) streak day `day` falls in.
    public func week(ofDay day: Int) -> Int { (max(day, 1) - 1) / length + 1 }

    /// Every rung of one week, for showing the ladder.
    public func rungs(forWeek week: Int) -> [StreakReward] {
        pep.map(StreakReward.pep) + [.egg(week.isMultiple(of: bigEggEvery) ? bigEgg : egg)]
    }
}

/// One of the day's three quests. The id is its reward's ledger id, so it pays once.
public struct Quest: Hashable, Sendable, Identifiable {
    public var id: String
    public var goal: QuestGoal
    public var reward: Int
}

/// Three small goals a day (an early one, a movement one and a care one), plus a streak ladder
/// for finishing all three. Picked the same way on every device; progress is computed, rewards are
/// ledger entries with fixed ids.
public struct QuestRules: Hashable, Sendable {
    public var version: Int
    /// Early-day goals: they pull you out for a morning or lunchtime stroll.
    public var early: [QuestGoal]
    public var movement: [QuestGoal]
    public var care: [QuestGoal]
    public var rewards: [Int]
    /// What finishing all three pays, escalating with the streak.
    public var ladder: StreakLadder

    public static let v1 = QuestRules(
        version: 1,
        early: [
            .stepsBefore(steps: 1_000, hour: 10), .stepsBefore(steps: 2_500, hour: 12),
            .activeMinutes(10, before: 13), .stepsBefore(steps: 1_500, hour: 11),
        ],
        movement: [
            .steps(5_000), .steps(7_500), .activeMinutes(20, before: nil), .activeMinutes(30, before: nil), .workout,
            .stepsAfter(steps: 1_500, hour: 17),
        ],
        care: [.care(.feed), .care(.play), .care(.wash), .gifts(2), .gifts(3)],
        rewards: [10, 15, 10], ladder: .v1)
}

/// What quests are measured against for one day.
public struct QuestInputs: Sendable {
    public var steps: [StepCount]
    public var samples: [ActivitySample]
    public var transactions: [PepTransaction]
    public var catalog: Catalog

    public init(steps: [StepCount], samples: [ActivitySample], transactions: [PepTransaction], catalog: Catalog) {
        self.steps = steps
        self.samples = samples
        self.transactions = transactions
        self.catalog = catalog
    }
}

public enum DailyQuests {
    /// The day's three quests.
    public static func quests(on day: Date, calendar: Calendar, rules: QuestRules = .v1) -> [Quest] {
        var rng = SeededRandom(seed: GameDay.seed(for: day, calendar: calendar, salt: UInt64(7_000 + rules.version)))
        let key = GameDay.key(for: day, calendar: calendar)
        return [rules.early, rules.movement, rules.care].enumerated().compactMap { index, pool in
            guard let goal = pool.randomElement(using: &rng) else { return nil }
            return Quest(
                id: "quest:\(key):\(goal.slug)", goal: goal, reward: rules.rewards[min(index, rules.rewards.count - 1)])
        }
    }

    /// How far along `quest` is on `day`: (current, target).
    public static func progress(
        of quest: Quest, on day: Date, inputs: QuestInputs, calendar: Calendar
    ) -> (current: Double, target: Double) {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        func at(_ hour: Int) -> Date { start.addingTimeInterval(TimeInterval(hour * 3_600)) }
        switch quest.goal {
        case .stepsBefore(let steps, let hour):
            return (stepCount(inputs.steps, from: start, to: at(hour)), Double(steps))
        case .stepsAfter(let steps, let hour):
            return (stepCount(inputs.steps, from: at(hour), to: end), Double(steps))
        case .steps(let steps):
            return (stepCount(inputs.steps, from: start, to: end), Double(steps))
        case .activeMinutes(let minutes, let hour):
            return (activeMinutes(inputs.samples, from: start, to: hour.map(at) ?? end), Double(minutes))
        case .workout:
            let done = inputs.samples.contains {
                $0.kind != .passive && !$0.isUserEntered && $0.end > start && $0.start < end
            }
            return (done ? 1 : 0, 1)
        case .care(let action):
            let done = inputs.transactions.contains { transaction in
                guard case .purchase(let itemID) = transaction.kind, transaction.date >= start, transaction.date < end
                else { return false }
                return inputs.catalog.item(id: itemID)?.category == action.category
            }
            return (done ? 1 : 0, 1)
        case .gifts(let count):
            let prefix = "moment:\(GameDay.key(for: day, calendar: calendar)):"
            return (Double(inputs.transactions.count { $0.id.hasPrefix(prefix) }), Double(count))
        }
    }

    public static func isDone(_ quest: Quest, on day: Date, inputs: QuestInputs, calendar: Calendar) -> Bool {
        let (current, target) = progress(of: quest, on: day, inputs: inputs, calendar: calendar)
        return current >= target
    }

    /// Hourly step buckets that fall inside the range (a bucket counts if it starts inside).
    private static func stepCount(_ steps: [StepCount], from start: Date, to end: Date) -> Double {
        steps.filter { $0.start >= start && $0.start < end }.reduce(0) { $0 + $1.steps }
    }

    private static func activeMinutes(_ samples: [ActivitySample], from start: Date, to end: Date) -> Double {
        ActivitySample.resolvingOverlaps(samples.filter { !$0.isUserEntered }).reduce(0) { total, sample in
            let overlap = min(sample.end, end).timeIntervalSince(max(sample.start, start))
            return total + max(0, overlap) / 60
        }
    }

    // MARK: - Ledger

    /// Ledger entries owed for `day`: each finished quest and, once all are done, that streak
    /// day's ladder reward (Pep on the `quests-done` entry, or an egg token beside it). Entries
    /// already in `inputs.transactions` are skipped, so calling this again (on either device)
    /// never pays twice.
    public static func rewards(
        on day: Date, inputs: QuestInputs, calendar: Calendar, at now: Date, rules: QuestRules = .v1
    ) -> [PepTransaction] {
        let paid = Set(inputs.transactions.map(\.id))
        let quests = quests(on: day, calendar: calendar, rules: rules)
        let finished = quests.filter { isDone($0, on: day, inputs: inputs, calendar: calendar) }
        var owed = finished.filter { !paid.contains($0.id) }.map { quest in
            PepTransaction(
                id: quest.id, kind: .adjustment(reason: "Quest: \(quest.goal.slug)"), amount: quest.reward, date: now)
        }
        let allDone = allDoneID(on: day, calendar: calendar)
        guard finished.count == quests.count, !quests.isEmpty, !paid.contains(allDone) else { return owed }
        let marker = PepTransaction(id: allDone, kind: .adjustment(reason: "All quests done"), amount: 0, date: now)
        let streakDay = streak(at: day, transactions: inputs.transactions + [marker], calendar: calendar)
        switch rules.ladder.reward(forDay: streakDay) {
        case .pep(let amount):
            owed.append(
                PepTransaction(
                    id: allDone, kind: .adjustment(reason: "Streak day \(streakDay)"), amount: amount, date: now))
        case .egg(let eggID):
            owed.append(marker)
            owed.append(
                PepTransaction(
                    id: eggTokenID(on: day, eggID: eggID, calendar: calendar),
                    kind: .adjustment(reason: "Streak day \(streakDay): \(eggID)"), amount: 0, date: now))
        }
        return owed
    }

    /// "egg-token:2026-11-12:sparkle-egg": a free egg earned that day, waiting to be hatched.
    public static func eggTokenID(on day: Date, eggID: String, calendar: Calendar) -> String {
        "\(eggTokenPrefix)\(GameDay.key(for: day, calendar: calendar)):\(eggID)"
    }

    public static let eggTokenPrefix = "egg-token:"

    /// The egg id inside a token id.
    public static func eggID(fromToken tokenID: String) -> String? {
        guard tokenID.hasPrefix(eggTokenPrefix) else { return nil }
        let parts = tokenID.dropFirst(eggTokenPrefix.count).split(separator: ":", maxSplits: 1)
        return parts.count == 2 ? String(parts[1]) : nil
    }

    /// "quests-done:2026-11-12": all three finished that day. Its presence is what streaks count.
    public static func allDoneID(on day: Date, calendar: Calendar) -> String {
        "quests-done:\(GameDay.key(for: day, calendar: calendar))"
    }

    /// Days in a row with all quests done, counting back from today (or yesterday, while today
    /// is still in progress). One missed day is forgiven; two in a row end the streak.
    public static func streak(at date: Date, transactions: [PepTransaction], calendar: Calendar) -> Int {
        let done = Set(transactions.map(\.id).filter { $0.hasPrefix("quests-done:") })
        var day = calendar.startOfDay(for: date)
        var count = 0
        var missedInARow = 0
        if !done.contains(allDoneID(on: day, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        // A year back is plenty; streak days only exist since quests did.
        for _ in 0..<400 {
            if done.contains(allDoneID(on: day, calendar: calendar)) {
                count += 1
                missedInARow = 0
            } else {
                missedInARow += 1
                if missedInARow >= 2 { break }
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}
