import FitchiCore
import Foundation
import Testing

@testable import FitchiData

@Suite("Complication glance")
@MainActor
struct GlanceTests {
    @Test func glanceFollowsTheActivePetThroughSharedDefaults() throws {
        let suite = PetStoreTests()
        let store = suite.makeStore(try FitchiStore.makeContainer(inMemory: true), at: suite.start)
        #expect(
            store.glance == PetGlance(pet: nil, species: nil, hasEgg: true, backdropID: Catalog.defaultBackdropID))

        let pet = try store.hatchStarter(samples: [], force: true)
        let glance = store.glance
        #expect(glance.pet?.id == pet.id)
        #expect(glance.species?.id == pet.speciesID)
        #expect(!glance.hasEgg)

        let defaults = try #require(UserDefaults(suiteName: "glance-tests-\(UUID().uuidString)"))
        #expect(GlanceStore.load(from: defaults) == nil)
        GlanceStore.save(glance, to: defaults)
        #expect(GlanceStore.load(from: defaults) == glance)
    }
}
