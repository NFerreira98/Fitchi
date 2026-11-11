import Foundation
import Testing

@testable import FitchiCore

@Suite("Colour variants and shinies")
struct VariantTests {
    @Test func everyStarterHasVariantsAndAShiny() {
        for id in ["dog", "cat", "axolotl"] {
            let species = TestSupport.catalog.species(id: id)
            #expect(species?.variants.isEmpty == false, "\(id) has no variants")
            #expect(species?.shiny != nil, "\(id) has no shiny")
        }
    }

    @Test func shiniesAreRareButHappen() throws {
        let axolotl = try #require(TestSupport.catalog.species(id: "axolotl"))
        var rng = SeededRandom(seed: 7)
        let rolls = (0..<64_000).compactMap { _ in VariantRules.v1.roll(for: axolotl, using: &rng) }
        let shinies = rolls.filter(\.isShiny).count
        #expect(rolls.count == 64_000)
        #expect((800...1_200).contains(shinies), "expected about 1 in 64, got \(shinies)")
        #expect(rolls.filter(\.isShiny).allSatisfy { $0.id == axolotl.shiny?.id })
    }

    @Test func regularVariantsFollowTheirWeights() throws {
        let axolotl = try #require(TestSupport.catalog.species(id: "axolotl"))
        var rng = SeededRandom(seed: 11)
        var counts: [String: Int] = [:]
        for _ in 0..<10_000 {
            if let variant = VariantRules.v1.roll(for: axolotl, using: &rng), !variant.isShiny {
                counts[variant.id, default: 0] += 1
            }
        }
        // Weights 4 : 3 : 2 : 1
        #expect(counts["leucistic", default: 0] > counts["wild", default: 0])
        #expect(counts["golden", default: 0] > counts["melanoid", default: 0])
        #expect(Set(counts.keys) == Set(axolotl.variants.map(\.id)))
    }

    @Test func noShinyMeansNoShinyRoll() throws {
        let axolotl = try #require(TestSupport.catalog.species(id: "axolotl"))
        var plain = axolotl
        plain.shiny = nil
        var rng = SeededRandom(seed: 3)
        let always = VariantRules(version: 0, shinyChance: 1)
        #expect(always.roll(for: plain, using: &rng)?.isShiny == false)
        #expect(always.roll(for: axolotl, using: &rng)?.isShiny == true)
    }

    @Test func speciesWithoutVariantsRollNothing() throws {
        var rng = SeededRandom(seed: 3)
        let bunny = try #require(TestSupport.catalog.species(id: "bunny"))
        #expect(VariantRules.v1.roll(for: bunny, using: &rng) == nil)
    }

    @Test func hatchedPetsGetAVariant() throws {
        var rng = SeededRandom(seed: 5)
        let pet = try Hatchery.hatchStarter(from: TestSupport.catalog, at: TestSupport.date(hour: 8), using: &rng)
        let species = try #require(TestSupport.catalog.species(id: pet.speciesID))
        let variant = try #require(pet.variant)
        #expect(species.colorVariant(for: variant)?.id == variant.id)
    }

    @Test func petsSavedBeforeVariantsDecodeAndUseTheFirstColouring() throws {
        let axolotl = try #require(TestSupport.catalog.species(id: "axolotl"))
        var rng = SeededRandom(seed: 5)
        let pet = Hatchery.makePet(species: axolotl, at: TestSupport.date(hour: 8), using: &rng)
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(pet)) as? [String: Any])
        json["variant"] = nil
        let old = try JSONDecoder().decode(Pet.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.variant == nil)
        #expect(!old.isShiny)
        #expect(axolotl.colorVariant(for: old.variant)?.id == "leucistic")
    }

    @Test func validationCatchesBadColours() throws {
        var catalog = TestSupport.catalog
        let index = try #require(catalog.species.firstIndex { $0.id == "cat" })
        catalog.species[index].variants.append(
            ColorVariant(
                id: "oops", name: "Oops", weight: 0, colors: ["body": "pink", "fur": "#FFFFFF"], pattern: "plaid")
        )
        let problems = catalog.validate()
        #expect(problems.contains("Species 'cat' variant 'oops' must have a positive weight"))
        #expect(problems.contains("Species 'cat' variant 'oops' colour 'body' is not #RRGGBB"))
        #expect(problems.contains("Species 'cat' variant 'oops' is missing colour 'belly'"))
        #expect(problems.contains("Species 'cat' variant 'oops' has unknown colour slot 'fur'"))
        #expect(problems.contains("Species 'cat' variant 'oops' has unknown pattern 'plaid'"))
    }
}
