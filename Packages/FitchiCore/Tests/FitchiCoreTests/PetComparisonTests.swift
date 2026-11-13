import Foundation
import Testing

@testable import FitchiCore

@Suite("Comparing pets")
struct PetComparisonTests {
    let catalog = TestSupport.catalog

    func pet(_ name: String, _ species: String, appetite: Double, tidiness: Double, personality: Personality, day: Int)
        -> Pet
    {
        Pet(
            name: name, speciesID: species,
            traits: PetTraits(appetite: appetite, playfulness: 0.5, stamina: 0.5, tidiness: tidiness),
            personality: personality, hatchedAt: TestSupport.date(2026, 3, day), variant: PetVariant(id: "honey"))
    }

    @Test func traitsAndNeedsSideBySide() throws {
        let biscuit = pet("Biscuit", "dog", appetite: 0.9, tidiness: 0.2, personality: .glutton, day: 1)
        let maple = pet("Maple", "dog", appetite: 0.6, tidiness: 0.5, personality: .neatFreak, day: 3)
        let comparison = PetComparison(pets: [biscuit, maple], catalog: catalog)
        let appetite = try #require(comparison.traits.first { $0.id == "appetite" })
        #expect(appetite.values == [0.9, 0.6] && appetite.standout == 0)
        let playful = try #require(comparison.traits.first { $0.id == "playfulness" })
        #expect(playful.standout == nil, "a tie stands out for nobody")
        // Hunger: 1.24 × 1.25 (glutton) against 1.06 × 1: Maple is easier to keep fed.
        let hunger = try #require(comparison.needs.first { $0.id == "hunger" })
        #expect(abs(hunger.values[0] - 1.55) < 0.001 && abs(hunger.values[1] - 1.06) < 0.001)
        #expect(hunger.standout == 1)
        // Cleanliness: 1.18 against 1.0 × 0.8 (neat freak).
        #expect(comparison.needs.first { $0.id == "cleanliness" }?.standout == 1)
        #expect(comparison.notes == ["Same species and colouring", "Different personalities", "Biscuit hatched first"])
    }

    @Test func threeAtOnceAndDifferentSpecies() {
        let pets = [
            pet("A", "dog", appetite: 0.5, tidiness: 0.5, personality: .hyper, day: 2),
            pet("B", "cat", appetite: 0.5, tidiness: 0.5, personality: .hyper, day: 2),
            pet("C", "cat", appetite: 0.8, tidiness: 0.5, personality: .hyper, day: 2),
        ]
        let comparison = PetComparison(pets: pets, catalog: catalog)
        #expect(comparison.traits.allSatisfy { $0.values.count == 3 })
        #expect(comparison.traits.first { $0.id == "appetite" }?.standout == 2)
        #expect(comparison.notes == ["Different species", "Same personality"])
    }
}
