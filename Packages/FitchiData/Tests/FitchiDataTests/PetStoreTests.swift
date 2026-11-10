import FitchiCore
import Foundation
import SwiftData
import Testing
@testable import FitchiData

@Suite("Pet store")
@MainActor
struct PetStoreTests {
    let catalog: Catalog = {
        let content = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Content")
        return (try? Catalog.load(from: content)) ?? Catalog(species: [], items: [], eggs: [], achievements: [])
    }()
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    func makeStore(_ container: ModelContainer, at date: Date) -> PetStore {
        let store = PetStore(repository: GameRepository(container: container), catalog: catalog, clock: FixedClock(date))
        store.load()
        return store
    }

    func walk(after date: Date, minutes: Double) -> ActivitySample {
        ActivitySample(id: "walk", kind: .walk, start: date + 60, end: date + 60 + minutes * 60)
    }

    @Test func newPlayerGetsOneEggThatSurvivesRelaunch() throws {
        let container = try FitchiStore.makeContainer(inMemory: true)
        let first = makeStore(container, at: start)
        #expect(first.status == .ready)
        #expect(first.pendingEgg?.grantedAt == start)
        #expect(first.activePet == nil)

        let relaunched = makeStore(container, at: start + 3600)
        #expect(relaunched.pendingEgg?.grantedAt == start)
    }

    @Test func eggWontHatchEarlyThenHatchesAfterAWalk() throws {
        let store = makeStore(try FitchiStore.makeContainer(inMemory: true), at: start)
        #expect(throws: PetStore.HatchFailure.notReady) { try store.hatchStarter(samples: [walk(after: start, minutes: 2)]) }

        let pet = try store.hatchStarter(samples: [walk(after: start, minutes: 6)])
        #expect(store.activePet?.id == pet.id)
        #expect(store.pendingEgg == nil)
        #expect(store.species(of: pet)?.rarity == .common)
        #expect(throws: PetStore.HatchFailure.alreadyHatched) { try store.hatchStarter(samples: [], force: true) }
    }

    @Test func hatchedAndRenamedPetIsSavedAndNoNewEggAppears() throws {
        let container = try FitchiStore.makeContainer(inMemory: true)
        let store = makeStore(container, at: start)
        let pet = try store.hatchStarter(samples: [], force: true)
        store.rename(pet.id, to: "  Sir Wiggles ")
        store.rename(pet.id, to: "   ")

        let relaunched = makeStore(container, at: start + 86_400)
        #expect(relaunched.activePet?.name == "Sir Wiggles")
        #expect(relaunched.activePet?.id == pet.id)
        #expect(relaunched.pendingEgg == nil)
        #expect(relaunched.starterEgg?.hatchedPetID == pet.id)
    }

    @Test func missingCatalogFailsClearly() throws {
        let empty = Catalog(species: [], items: [], eggs: [], achievements: [])
        let store = PetStore(repository: GameRepository(container: try FitchiStore.makeContainer(inMemory: true)), catalog: empty)
        store.load()
        #expect(store.status == .failed("Couldn't load the pet catalog."))
    }
}

@Suite("Care and Pep ledger")
@MainActor
struct CareLedgerTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func welcomeBonusOnceAndSpendingSurvivesRelaunch() throws {
        let container = try FitchiStore.makeContainer(inMemory: true)
        let suite = PetStoreTests()
        let store = suite.makeStore(container, at: start)
        #expect(store.wallet(earnings: []).balance == 100)
        let pet = try store.hatchStarter(samples: [], force: true)

        // Newborns are full, so come back later when the pet is hungry.
        let later = suite.makeStore(container, at: start + 12 * 3600)
        #expect(throws: Never.self) { try later.care(.feed, for: pet.id, earnings: []) }
        let spent = 100 - later.wallet(earnings: []).balance
        #expect(spent > 0)

        let relaunched = suite.makeStore(container, at: start + 13 * 3600)
        #expect(relaunched.wallet(earnings: []).balance == 100 - spent)
        #expect(relaunched.transactions.filter { $0.kind == .welcomeBonus }.count == 1)
        let fed = try #require(relaunched.activePet)
        #expect(fed.value(of: .hunger, at: start + 13 * 3600, in: relaunched.decay) > 80)
    }

    @Test func fullPetIsNotChargedAndEarningsCount() throws {
        let store = PetStoreTests().makeStore(try FitchiStore.makeContainer(inMemory: true), at: start)
        let pet = try store.hatchStarter(samples: [], force: true)
        #expect(throws: QuickCareError.alreadySatisfied(.hunger)) { try store.care(.feed, for: pet.id, earnings: []) }
        let earning = Earning(sourceID: "walk", day: start, amount: 40, rulesVersion: 1)
        #expect(store.wallet(earnings: [earning]).balance == 140)
    }
}
