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
