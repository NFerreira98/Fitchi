import FitchiCore
import Foundation

/// A quest with how far along it is today.
public struct QuestStatus: Hashable, Sendable, Identifiable {
    public var quest: Quest
    public var current: Double
    public var target: Double
    public var id: String { quest.id }
    public var isDone: Bool { current >= target }
}

/// Pet moments (little gifts through the day) and daily quests with a streak. Everything is
/// computed from the clock, Health data and the ledger; rewards are ledger entries with fixed
/// ids, so they sync and never pay twice.
extension PetStore {
    var calendar: Calendar { decay.calendar }

    // MARK: - Moments

    /// The gift waiting right now, if any: open, unclaimed, and with a pet around to find it.
    public func openMoment(at date: Date) -> PetMoment? {
        guard let pet = activePet, pet.mood(at: date, in: decay).condition.acceptsCare,
            let moment = PetMoments.open(at: date, calendar: calendar),
            !transactions.contains(where: { $0.id == moment.id })
        else { return nil }
        return moment
    }

    /// Collects the open gift. Returns it, or nil if there was nothing to collect.
    @discardableResult
    public func collectGift() -> PetMoment? {
        let now = clock.now
        guard let moment = openMoment(at: now) else { return nil }
        append([.momentGift(moment, at: now)])
        return moment
    }

    /// Gift ids already collected, for the complication.
    var collectedGiftIDs: [String] {
        transactions.map(\.id).filter { $0.hasPrefix("moment:") }
    }

    // MARK: - Quests

    private func questInputs(samples: [ActivitySample], steps: [StepCount]) -> QuestInputs {
        QuestInputs(steps: steps, samples: samples, transactions: transactions, catalog: catalog)
    }

    /// Today's three quests and their progress.
    public func todaysQuests(samples: [ActivitySample], steps: [StepCount]) -> [QuestStatus] {
        let now = clock.now
        let inputs = questInputs(samples: samples, steps: steps)
        return DailyQuests.quests(on: now, calendar: calendar).map { quest in
            let (current, target) = DailyQuests.progress(of: quest, on: now, inputs: inputs, calendar: calendar)
            return QuestStatus(quest: quest, current: current, target: target)
        }
    }

    /// Days in a row with every quest done (one missed day forgiven).
    public var questStreak: Int {
        DailyQuests.streak(at: clock.now, transactions: transactions, calendar: calendar)
    }

    /// Pays whatever today's quests have earned and queues notices for them. Safe to call often
    /// and from both devices.
    @discardableResult
    public func claimQuests(samples: [ActivitySample], steps: [StepCount]) -> [PepTransaction] {
        guard status == .ready, activePet != nil else { return [] }
        let now = clock.now
        let owed = DailyQuests.rewards(
            on: now, inputs: questInputs(samples: samples, steps: steps), calendar: calendar, at: now)
        guard !owed.isEmpty else { return [] }
        append(owed)
        let quests = DailyQuests.quests(on: now, calendar: calendar)
        for entry in owed {
            if let quest = quests.first(where: { $0.id == entry.id }) {
                questNotices.append(.quest(quest))
            } else if let eggID = DailyQuests.eggID(fromToken: entry.id) {
                questNotices.append(.allDone(reward: .egg(eggID), streak: questStreak))
            } else if entry.id.hasPrefix("quests-done:"), entry.amount > 0 {
                questNotices.append(.allDone(reward: .pep(entry.amount), streak: questStreak))
            }
        }
        return owed
    }

    /// Whether all of today's quests are done (the ladder has moved up today).
    public var questsDoneToday: Bool {
        transactions.contains { $0.id == DailyQuests.allDoneID(on: clock.now, calendar: calendar) }
    }

    // MARK: - Reward eggs

    /// A free egg from the streak ladder, waiting to be hatched.
    public struct RewardEgg: Hashable, Sendable, Identifiable {
        public var tokenID: String
        public var egg: EggType
        public var id: String { tokenID }
    }

    private static func openedID(_ tokenID: String) -> String { "egg-opened:" + tokenID }

    /// Earned eggs not hatched yet, oldest first.
    public var rewardEggs: [RewardEgg] {
        let ids = Set(transactions.map(\.id))
        return transactions.compactMap { entry in
            guard let eggID = DailyQuests.eggID(fromToken: entry.id), !ids.contains(Self.openedID(entry.id)),
                let egg = catalog.egg(id: eggID)
            else { return nil }
            return RewardEgg(tokenID: entry.id, egg: egg)
        }
    }

    /// Hatches a free egg: same odds, duplicate protection and repeat refund as a bought one, at
    /// no cost. Only the phone offers this, so one egg can't hatch on two devices at once.
    /// The season, weather and time of day right now: what special colourings can hatch.
    public var hatchMoment: HatchMoment { HatchMoment(at: clock.now) }

    public func hatchRewardEgg(_ reward: RewardEgg) throws(PurchaseError) -> HatchResult {
        guard rewardEggs.contains(reward) else { throw .notSaved }
        let now = clock.now
        // A wallet with exactly the egg's price, so the shop's purchase nets out to nothing.
        var wallet = Wallet(transactions: [
            PepTransaction(id: "reward-egg", kind: .adjustment(reason: "free egg"), amount: reward.egg.price, date: now)
        ])
        var rng = SystemRandomNumberGenerator()
        var hatch: HatchResult
        do {
            hatch = try Shop.buyEgg(
                reward.egg, from: catalog, wallet: &wallet, at: now,
                history: HatchHistory(pets: roster.pets, catalog: catalog), moment: hatchMoment, using: &rng)
        } catch {
            throw .hatch
        }
        roster.add(hatch.pet, at: now, in: decay)
        hatch.pet = roster[hatch.pet.id] ?? hatch.pet
        try? repository?.save(hatch.pet, at: now)
        var entries = [
            PepTransaction(
                id: Self.openedID(reward.tokenID), kind: .adjustment(reason: "Hatched \(reward.egg.id)"), amount: 0,
                date: now)
        ]
        // Keep the repeat refund (if any); drop the stand-in funding and purchase.
        entries += wallet.transactions.filter { $0.id.hasPrefix("repeat-refund:") }
        append(entries)
        return hatch
    }

    /// The quest notice on screen has been seen.
    public func dismissQuestNotice() {
        guard !questNotices.isEmpty else { return }
        questNotices.removeFirst()
    }

    private func append(_ entries: [PepTransaction]) {
        let new = entries.filter { entry in !transactions.contains { $0.id == entry.id } }
        guard !new.isEmpty else { return }
        try? repository?.append(new)
        transactions.append(contentsOf: new)
        didChange()
    }
}
