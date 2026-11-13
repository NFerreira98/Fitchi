import FitchiCore
import Foundation
import Testing

@testable import FitchiData

@Suite("Shop, eggs and collection")
@MainActor
struct ShopStoreTests {
    let suite = PetStoreTests()

    /// Earnings big enough to afford anything in the catalog.
    let rich = [Earning(sourceID: "big-walk", day: Date(timeIntervalSince1970: 0), amount: 10_000, rulesVersion: 2)]

    func makeStore() throws -> PetStore {
        let store = suite.makeStore(try FitchiStore.makeContainer(inMemory: true), at: suite.start)
        _ = try store.hatchStarter(samples: [], force: true)
        return store
    }

    @Test func buyingTheBackdropSpendsPepAndSelectsOnlyOwnedOnes() throws {
        let store = try makeStore()
        let pond = try #require(store.catalog.item(id: "backdrop-pond"))
        #expect(!store.selectBackdrop(pond.id))
        #expect(throws: PetStore.PurchaseError.shop(.insufficientFunds(price: pond.price, balance: 100))) {
            try store.buy(pond, earnings: [])
        }
        try store.buy(pond, earnings: rich)
        #expect(store.wallet(earnings: rich).balance == 10_100 - pond.price)
        #expect(store.selectBackdrop(pond.id))
        #expect(store.inventory.activeBackdropID == pond.id)
    }

    @Test func accessoriesAreWornOnlyOnceOwnedAndSurviveARestore() throws {
        let store = try makeStore()
        let pet = try #require(store.activePet)
        let hat = try #require(store.catalog.item(id: "party-hat"))
        let crown = try #require(store.catalog.item(id: "flower-crown"))
        #expect(!store.wear(hat.id, on: pet.id), "not owned yet")
        #expect(!store.wear("kibble", on: pet.id), "not an accessory")

        try store.buy(hat, earnings: rich)
        try store.buy(crown, earnings: rich)
        #expect(store.wear(hat.id, on: pet.id))
        #expect(store.wear(crown.id, on: pet.id))
        #expect(store.roster[pet.id]?.equipped == [.head: crown.id], "one item per slot")

        // A reinstalled watch gets the outfit back from the phone's backup.
        let snapshot = try #require(store.snapshot(installDate: suite.start))
        let fresh = suite.makeStore(try FitchiStore.makeContainer(inMemory: true), at: suite.start + 60)
        #expect(fresh.restore(from: snapshot))
        #expect(fresh.roster[pet.id]?.equipped == [.head: crown.id])

        store.takeOff(.head, from: pet.id)
        #expect(store.roster[pet.id]?.equipped.isEmpty == true)
    }

    @Test func testPepCanBeGrantedAndTakenBackButNotPastWhatWasSpent() throws {
        let store = try makeStore()
        store.grantTestPep(1_000)
        #expect(store.wallet(earnings: []).balance == 1_100)
        #expect(store.testPep == 1_000)
        try store.buy(try #require(store.catalog.item(id: "party-hat")), earnings: [])
        store.removeTestPep(earnings: [])
        #expect(store.wallet(earnings: []).balance == 0, "the hat stays bought; only what's left is removed")
        #expect(store.testPep == 1_000 - 980)
    }

    @Test func eggsHatchARestingPetThatFillsTheCollection() throws {
        let store = try makeStore()
        let starter = try #require(store.activePet)
        let egg = try #require(store.catalog.eggs.first)
        let before = store.collection.foundCount
        let newcomer = try store.buyEgg(egg, earnings: rich).pet
        #expect(store.roster.pets.count == 2)
        #expect(store.activePet?.id == starter.id, "the starter stays on the watch")
        #expect(store.roster[newcomer.id]?.isActive == false)
        #expect(store.collection.foundCount >= before)

        store.setActive(newcomer.id)
        #expect(store.activePet?.id == newcomer.id)
        #expect(store.roster[starter.id]?.isActive == false)
    }

    @Test func aPurchaseSurvivesAStaleInventoryFromTheOtherDevice() throws {
        // The phone buys the pond; meanwhile the watch saves a newer inventory that predates it.
        let phone = try makeStore()
        let watch = PetStore(
            repository: GameRepository(container: try FitchiStore.makeContainer(inMemory: true)),
            catalog: suite.catalog,
            clock: FixedClock(suite.start + 3600))
        watch.load()
        #expect(watch.restore(from: try #require(phone.snapshot(installDate: suite.start))))
        try phone.buy(try #require(phone.catalog.item(id: "backdrop-pond")), earnings: rich)
        // The watch saves its (pond-less) inventory later than the phone's purchase.
        #expect(watch.selectBackdrop(Catalog.defaultBackdropID))
        let feedLater = try #require(watch.snapshot(installDate: suite.start))

        #expect(phone.restore(from: feedLater))
        #expect(phone.inventory.owns("backdrop-pond"))
        #expect(watch.restore(from: try #require(phone.snapshot(installDate: suite.start))))
        #expect(watch.inventory.owns("backdrop-pond"))
    }
}

@Suite("Achievements in the store")
@MainActor
struct AchievementStoreTests {
    let suite = PetStoreTests()

    @Test func rewardsArePaidOnceAndCelebrated() throws {
        let store = suite.makeStore(try FitchiStore.makeContainer(inMemory: true), at: suite.start)
        #expect(store.claimAchievements(samples: [], steps: [], earnings: [], installDate: suite.start).isEmpty)
        _ = try store.hatchStarter(samples: [], force: true)
        let before = store.wallet(earnings: []).balance

        let unlocked = store.claimAchievements(samples: [], steps: [], earnings: [], installDate: suite.start)
        let friend = try #require(unlocked.first { $0.id == "first-friend" })
        #expect(store.wallet(earnings: []).balance == before + unlocked.reduce(0) { $0 + $1.reward })
        #expect(store.unlockedAchievements[friend.id] == suite.start)
        #expect(store.celebrations.map(\.id) == unlocked.map(\.id))
        store.dismissCelebration()
        #expect(store.celebrations.count == unlocked.count - 1)

        // Claiming again pays nothing new, and a merged copy from another device doesn't double up.
        #expect(store.claimAchievements(samples: [], steps: [], earnings: [], installDate: suite.start).isEmpty)
        let other = PetStore(
            repository: GameRepository(container: try FitchiStore.makeContainer(inMemory: true)),
            catalog: suite.catalog,
            clock: FixedClock(suite.start + 60))
        other.load()
        other.restore(from: try #require(store.snapshot(installDate: suite.start)))
        #expect(other.claimAchievements(samples: [], steps: [], earnings: [], installDate: suite.start).isEmpty)
        #expect(other.wallet(earnings: []).balance == store.wallet(earnings: []).balance)
    }
}
