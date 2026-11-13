import Foundation
import Testing

@testable import FitchiCore

@Suite("Pet moments")
struct PetMomentTests {
    let calendar = TestSupport.calendar

    @Test func threeDaytimeMomentsADayTheSameEverywhere() {
        let day = TestSupport.date(2026, 3, 9)
        let moments = PetMoments.moments(on: day, calendar: calendar)
        #expect(moments.count == 3)
        #expect(moments == PetMoments.moments(on: TestSupport.date(2026, 3, 9, hour: 23), calendar: calendar))
        for (moment, window) in zip(moments, MomentRules.v1.windows) {
            let opensAt = Int(moment.opens.timeIntervalSince(calendar.startOfDay(for: day)) / 60)
            #expect(window.contains(opensAt))
            #expect(moment.closes.timeIntervalSince(moment.opens) == 7_200)
            #expect(moment.pep >= 5 && moment.pep <= 25)
        }
        #expect(moments.map(\.id) == ["moment:2026-03-09:0", "moment:2026-03-09:1", "moment:2026-03-09:2"])
    }

    @Test func momentsMoveAroundFromDayToDay() {
        let opens = (1...10).map { PetMoments.moments(on: TestSupport.date(2026, 3, $0), calendar: calendar)[0].opens }
        let minutes = Set(
            opens.map { calendar.component(.minute, from: $0) + calendar.component(.hour, from: $0) * 60 })
        #expect(minutes.count > 3)
    }

    @Test func openFindsTheCurrentMomentAndNothingAtNight() throws {
        let day = TestSupport.date(2026, 3, 9)
        let first = try #require(PetMoments.moments(on: day, calendar: calendar).first)
        #expect(PetMoments.open(at: first.opens.addingTimeInterval(60), calendar: calendar) == first)
        #expect(PetMoments.open(at: TestSupport.date(2026, 3, 9, hour: 2), calendar: calendar) == nil)
        #expect(PetMoments.open(at: TestSupport.date(2026, 3, 9, hour: 23), calendar: calendar) == nil)
    }

    @Test func aGiftPaysOnce() throws {
        let moment = try #require(PetMoments.moments(on: TestSupport.date(), calendar: calendar).first)
        var wallet = Wallet()
        wallet.record(.momentGift(moment, at: moment.opens))
        wallet.record(.momentGift(moment, at: moment.opens))
        #expect(wallet.balance == moment.pep)
    }
}

@Suite("Daily quests")
struct DailyQuestTests {
    let calendar = TestSupport.calendar
    let day = TestSupport.date(2026, 3, 9)
    let catalog = TestSupport.catalog

    func at(_ hour: Int, _ minute: Int = 0) -> Date { TestSupport.date(2026, 3, 9, hour: hour, minute: minute) }

    func quest(_ goal: QuestGoal) -> Quest { Quest(id: "quest:test:\(goal.slug)", goal: goal, reward: 10) }

    func inputs(
        steps: [StepCount] = [], samples: [ActivitySample] = [], transactions: [PepTransaction] = []
    ) -> QuestInputs {
        QuestInputs(steps: steps, samples: samples, transactions: transactions, catalog: catalog)
    }

    @Test func threeQuestsADayOneFromEachGroup() {
        let quests = DailyQuests.quests(on: day, calendar: calendar)
        #expect(quests.count == 3)
        #expect(QuestRules.v1.early.contains(quests[0].goal))
        #expect(QuestRules.v1.movement.contains(quests[1].goal))
        #expect(QuestRules.v1.care.contains(quests[2].goal))
        #expect(quests == DailyQuests.quests(on: at(21), calendar: calendar))
    }

    @Test func stepsBeforeAnHourOnlyCountTheMorning() {
        let goal = quest(.stepsBefore(steps: 1_000, hour: 12))
        let steps = [
            StepCount(start: at(9), end: at(10), steps: 600), StepCount(start: at(11), end: at(12), steps: 300),
            StepCount(start: at(12), end: at(13), steps: 5_000),
        ]
        let progress = DailyQuests.progress(of: goal, on: day, inputs: inputs(steps: steps), calendar: calendar)
        #expect(progress.current == 900 && progress.target == 1_000)
    }

    @Test func activeMinutesClipToTheCutoffAndSkipHandEntered() {
        let goal = quest(.activeMinutes(10, before: 13))
        let samples = [
            ActivitySample(id: "a", kind: .walk, start: at(12, 55), end: at(13, 30)),
            ActivitySample(id: "b", kind: .run, start: at(8), end: at(9), isUserEntered: true),
        ]
        let progress = DailyQuests.progress(of: goal, on: day, inputs: inputs(samples: samples), calendar: calendar)
        #expect(progress.current == 5)
    }

    @Test func careQuestsCountTodaysCareOfThatKind() throws {
        let food = try #require(catalog.items.first { $0.category == .food })
        let toy = try #require(catalog.items.first { $0.category == .toy })
        let yesterday = TestSupport.date(2026, 3, 8)
        let ledger: [PepTransaction] = [
            .purchase(itemID: toy.id, price: toy.price, at: at(10)),
            .purchase(itemID: food.id, price: food.price, at: yesterday),
        ]
        let feed = quest(.care(.feed))
        let play = quest(.care(.play))
        #expect(!DailyQuests.isDone(feed, on: day, inputs: inputs(transactions: ledger), calendar: calendar))
        #expect(DailyQuests.isDone(play, on: day, inputs: inputs(transactions: ledger), calendar: calendar))
    }

    @Test func giftQuestsCountTodaysMoments() {
        let moments = PetMoments.moments(on: day, calendar: calendar)
        let ledger = moments.prefix(2).map { PepTransaction.momentGift($0, at: $0.opens) }
        #expect(DailyQuests.isDone(quest(.gifts(2)), on: day, inputs: inputs(transactions: ledger), calendar: calendar))
        #expect(
            !DailyQuests.isDone(quest(.gifts(3)), on: day, inputs: inputs(transactions: ledger), calendar: calendar))
    }

    /// A ledger where every quest on `days` is done (pays them through `rewards`).
    func ledger(completing days: [Date]) -> [PepTransaction] {
        var ledger: [PepTransaction] = []
        for day in days {
            let ids = DailyQuests.quests(on: day, calendar: calendar).map(\.id)
            ledger += ids.map { PepTransaction(id: $0, kind: .adjustment(reason: "test"), amount: 10, date: day) }
            ledger.append(
                PepTransaction(
                    id: DailyQuests.allDoneID(on: day, calendar: calendar), kind: .adjustment(reason: "test"),
                    amount: 15,
                    date: day))
        }
        return ledger
    }

    func march(_ days: ClosedRange<Int>) -> [Date] { days.map { TestSupport.date(2026, 3, $0) } }

    @Test func streaksForgiveOneMissedDayButNotTwo() {
        // Done on the 1st–4th, missed the 5th, done the 6th–8th; today (9th) still in progress.
        let ledger = ledger(completing: march(1...4) + march(6...8))
        #expect(DailyQuests.streak(at: at(9), transactions: ledger, calendar: calendar) == 7)
        // Missing the 5th and 6th ends it: only the 7th and 8th count.
        let broken = self.ledger(completing: march(1...4) + march(7...8))
        #expect(DailyQuests.streak(at: at(9), transactions: broken, calendar: calendar) == 2)
        #expect(DailyQuests.streak(at: at(9), transactions: [], calendar: calendar) == 0)
    }

    @Test func rewardsPayEachQuestOnceThenTheSeventhDayEgg() throws {
        // Six days already done; today every quest is satisfied by a generous day.
        let history = ledger(completing: march(3...8))
        let quests = DailyQuests.quests(on: day, calendar: calendar)
        // Satisfy anything: lots of steps all day, a long workout, care of every kind, three gifts.
        let steps = (0..<24).map { StepCount(start: at($0), end: at($0) + 3_600, steps: 2_000) }
        let samples = [ActivitySample(id: "w", kind: .run, start: at(7), end: at(8))]
        let care = catalog.items.filter { [.food, .toy, .hygiene].contains($0.category) }
            .map { PepTransaction.purchase(itemID: $0.id, price: 0, at: at(9)) }
        let gifts = PetMoments.moments(on: day, calendar: calendar).map { PepTransaction.momentGift($0, at: $0.opens) }
        var all = inputs(steps: steps, samples: samples, transactions: history + care + gifts)

        let owed = DailyQuests.rewards(on: day, inputs: all, calendar: calendar, at: at(20))
        let ids = Set(owed.map(\.id))
        #expect(ids.isSuperset(of: quests.map(\.id)))
        #expect(ids.contains(DailyQuests.allDoneID(on: day, calendar: calendar)))
        #expect(ids.contains("egg-token:2026-03-09:sparkle-egg"), "seventh day in a row: a free egg")
        #expect(owed.first { $0.id == DailyQuests.allDoneID(on: day, calendar: calendar) }?.amount == 0)
        #expect(DailyQuests.eggID(fromToken: "egg-token:2026-03-09:sparkle-egg") == "sparkle-egg")

        all.transactions += owed
        #expect(DailyQuests.rewards(on: day, inputs: all, calendar: calendar, at: at(21)).isEmpty, "never pays twice")
    }
}

@Suite("Streak ladder")
struct StreakLadderTests {
    let ladder = StreakLadder.v1

    @Test func aWeekClimbsThroughPepToAnEgg() {
        let week = (1...7).map(ladder.reward(forDay:))
        #expect(week == [.pep(15), .pep(20), .pep(25), .pep(35), .pep(45), .pep(60), .egg("sparkle-egg")])
        #expect(ladder.reward(forDay: 8) == .pep(15), "then it starts over")
        #expect(ladder.reward(forDay: 14) == .egg("sparkle-egg"))
        #expect(ladder.reward(forDay: 28) == .egg("golden-egg"), "every fourth week ends with a golden egg")
        #expect(ladder.reward(forDay: 56) == .egg("golden-egg"))
        #expect(ladder.week(ofDay: 7) == 1 && ladder.week(ofDay: 8) == 2)
    }

    @Test func ladderEggsExistInTheCatalog() {
        for egg in [ladder.egg, ladder.bigEgg] {
            #expect(TestSupport.catalog.egg(id: egg) != nil, "\(egg) is not in eggs.json")
        }
    }
}

@Suite("Afterglow")
struct AfterglowTests {
    func at(_ hour: Int, _ minute: Int = 0) -> Date { TestSupport.date(2026, 3, 9, hour: hour, minute: minute) }

    @Test func fadesOverAnHourAfterARealWorkout() {
        let run = ActivitySample(id: "run", kind: .run, start: at(7), end: at(7, 30))
        #expect(Afterglow.level(at: at(7, 30), samples: [run]) == 1)
        #expect(abs(Afterglow.level(at: at(8), samples: [run]) - 0.5) < 0.001)
        #expect(Afterglow.level(at: at(8, 30), samples: [run]) == 0)
        #expect(Afterglow.level(at: at(7, 15), samples: [run]) == 0, "not until it's over")
    }

    @Test func passiveShortAndHandEnteredDontCount() {
        let samples = [
            ActivitySample(id: "p", kind: .passive, start: at(7), end: at(7, 30)),
            ActivitySample(id: "s", kind: .walk, start: at(7), end: at(7, 5)),
            ActivitySample(id: "h", kind: .run, start: at(7), end: at(7, 30), isUserEntered: true),
        ]
        #expect(Afterglow.level(at: at(7, 31), samples: samples) == 0)
    }
}
