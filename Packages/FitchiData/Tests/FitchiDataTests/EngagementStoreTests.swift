import FitchiCore
import Foundation
import Testing

@testable import FitchiData

@Suite("Gifts and quests")
@MainActor
struct EngagementStoreTests {
    let suite = PetStoreTests()

    /// A store with a hatched pet, its clock at `date`.
    func makeStore(at date: Date) throws -> PetStore {
        let store = suite.makeStore(try FitchiStore.makeContainer(inMemory: true), at: date)
        _ = try store.hatchStarter(samples: [], force: true)
        return store
    }

    var firstMoment: PetMoment {
        PetMoments.moments(on: suite.start, calendar: DecayContext().calendar)[0]
    }

    @Test func aGiftCanBeCollectedOnceWhileItsOpen() throws {
        let moment = firstMoment
        let store = try makeStore(at: moment.opens.addingTimeInterval(60))
        let before = store.wallet(earnings: []).balance
        #expect(store.openMoment(at: moment.opens.addingTimeInterval(60)) == moment)
        #expect(store.collectGift() == moment)
        #expect(store.collectGift() == nil, "already collected")
        #expect(store.wallet(earnings: []).balance == before + moment.pep)
        #expect(store.glance.collectedGifts?.contains(moment.id) == true)

        let late = try makeStore(at: moment.closes.addingTimeInterval(60))
        #expect(late.openMoment(at: moment.closes.addingTimeInterval(60)) != moment)
    }

    @Test func questsPayOnceQueueNoticesAndSurviveARestore() throws {
        let store = try makeStore(at: firstMoment.opens.addingTimeInterval(60))
        let calendar = DecayContext().calendar
        let midnight = calendar.startOfDay(for: suite.start)
        // A big day: steps every hour and an hour-long run.
        let steps = (0..<24).map {
            StepCount(
                start: midnight.addingTimeInterval(Double($0) * 3_600),
                end: midnight.addingTimeInterval(Double($0 + 1) * 3_600), steps: 3_000)
        }
        let run = ActivitySample(
            id: "run", kind: .run, start: midnight.addingTimeInterval(7 * 3_600),
            end: midnight.addingTimeInterval(8 * 3_600))

        let movementQuests = store.todaysQuests(samples: [run], steps: steps).dropLast()
        let allMet = movementQuests.allSatisfy { $0.isDone }
        #expect(allMet, "early and movement quests are met by a big day")
        let paid = store.claimQuests(samples: [run], steps: steps)
        #expect(paid.count == 2)
        #expect(store.questNotices.count == 2)
        let again = store.claimQuests(samples: [run], steps: steps)
        #expect(again.isEmpty, "never pays twice")
        store.dismissQuestNotice()
        #expect(store.questNotices.count == 1)

        // The rewards are ledger entries, so they come back with the backup.
        let snapshot = try #require(store.snapshot(installDate: suite.start))
        let fresh = suite.makeStore(try FitchiStore.makeContainer(inMemory: true), at: suite.start)
        #expect(fresh.restore(from: snapshot))
        #expect(Set(paid.map(\.id)).isSubset(of: Set(fresh.transactions.map(\.id))))
    }

    @Test func aStreakEggHatchesOnceForFree() throws {
        let store = try makeStore(at: suite.start)
        let token = PepTransaction(
            id: DailyQuests.eggTokenID(on: suite.start, eggID: "sparkle-egg", calendar: DecayContext().calendar),
            kind: .adjustment(reason: "test"), amount: 0, date: suite.start)
        store.transactions.append(token)
        let reward = try #require(store.rewardEggs.first)
        #expect(reward.egg.id == "sparkle-egg")
        let before = store.wallet(earnings: []).balance

        let hatch = try store.hatchRewardEgg(reward)
        #expect(store.roster.pets.count == 2)
        #expect(store.rewardEggs.isEmpty)
        #expect(store.wallet(earnings: []).balance == before + hatch.refund, "free, apart from any repeat refund")
        #expect(throws: PetStore.PurchaseError.notSaved) { try store.hatchRewardEgg(reward) }
    }
}
