import Foundation
import Testing

@testable import FitchiCore

@Suite("Duplicate protection")
struct DuplicateTests {
    let now = TestSupport.date()
    let catalog = TestSupport.catalog

    /// Every regular (non-shiny) collection entry, optionally of one rarity.
    func entries(_ rarity: Rarity? = nil) -> [CollectionEntry] {
        CollectionBook(catalog: catalog, pets: []).entries.filter {
            !$0.isShiny && (rarity == nil || $0.rarity == rarity)
        }
    }

    func hatches(
        _ eggID: String, _ history: HatchHistory, count: Int = 4_000, seed: UInt64 = 11
    ) throws -> [Pet] {
        let egg = try #require(catalog.egg(id: eggID))
        var rng = SeededRandom(seed: seed)
        return try (0..<count).map { _ in try Hatchery.hatch(egg, from: catalog, at: now, history: history, using: &rng)
        }
    }

    func rarity(_ pet: Pet) -> Rarity? { catalog.species(id: pet.speciesID)?.rarity }

    @Test func rarityOddsNeverChangeEvenWithPityActive() throws {
        // Everything found except the legendary, and plenty of repeats in a row.
        let found = Set(entries().filter { $0.rarity != .legendary }.map(\.id))
        let pets = try hatches("sparkle-egg", HatchHistory(found: found, repeatsInARow: 9))
        let legendaryShare = Double(pets.count { rarity($0) == .legendary }) / Double(pets.count)
        #expect(abs(legendaryShare - 0.01) < 0.006, "still 1%, not forced by pity")
        let uncommonShare = Double(pets.count { rarity($0) == .uncommon }) / Double(pets.count)
        #expect(abs(uncommonShare - 0.60) < 0.03)
    }

    @Test func coloringsNotYetFoundAreFavoured() throws {
        let found = Set(entries().filter { $0.speciesID == "axolotl" }.map(\.id))
        let commons = try hatches("meadow-egg", HatchHistory(found: found)).filter {
            rarity($0) == .common && !$0.isShiny
        }
        let axolotlShare = Double(commons.count { $0.speciesID == "axolotl" }) / Double(commons.count)
        // Without protection a third; with new finds weighted 4×, 1 / (1 + 4 + 4).
        #expect(abs(axolotlShare - 1.0 / 9) < 0.03)
    }

    @Test func pityGuaranteesTheLastNewColouringInTheRolledRarity() throws {
        let missing = try #require(entries(.common).first { $0.speciesID == "dog" })
        let found = Set(entries().map(\.id)).subtracting([missing.id])
        let pets = try hatches("meadow-egg", HatchHistory(found: found, repeatsInARow: 2), count: 500)
        for pet in pets where rarity(pet) == .common && !pet.isShiny {
            #expect(catalog.species(id: pet.speciesID)?.collectionID(for: pet.variant) == missing.id)
        }
        // One repeat short of pity, other commons still turn up.
        let early = try hatches("meadow-egg", HatchHistory(found: found, repeatsInARow: 1), count: 500)
        #expect(early.contains { rarity($0) == .common && $0.speciesID != "dog" })
    }

    @Test func pityDoesNothingWhenTheRarityIsComplete() throws {
        let found = Set(entries().map(\.id))
        let pets = try hatches("meadow-egg", HatchHistory(found: found, repeatsInARow: 5), count: 1_000)
        let commonShare = Double(pets.count { rarity($0) == .common }) / Double(pets.count)
        #expect(abs(commonShare - 0.8) < 0.04, "repeats are unavoidable, odds unchanged")
    }

    @Test func anExactRepeatRefundsAQuarterOnce() throws {
        let egg = try #require(catalog.egg(id: "meadow-egg"))
        let everything = HatchHistory(found: Set(CollectionBook(catalog: catalog, pets: []).entries.map(\.id)))
        var wallet = Wallet(transactions: [.welcomeBonus(1_000, at: now)])
        var rng = SeededRandom(seed: 5)
        let hatch = try Shop.buyEgg(egg, from: catalog, wallet: &wallet, at: now, history: everything, using: &rng)
        #expect(!hatch.isNewFind)
        #expect(hatch.refund == 150)
        #expect(wallet.balance == 1_000 - 600 + 150)
        // Recording the same refund again (say, after a sync) doesn't pay twice.
        wallet.record(.repeatRefund(petID: hatch.pet.id, eggID: egg.id, amount: 150, at: now))
        #expect(wallet.balance == 550)
    }

    @Test func historyReplaysTheRosterInHatchOrder() throws {
        let cat = try #require(catalog.species(id: "cat"))
        var rng = SeededRandom(seed: 1)
        let colour = try #require(cat.variants.first).id
        func pet(_ minutes: Double, _ variant: String) -> Pet {
            Hatchery.makePet(
                species: cat, at: now + minutes * 60, variant: PetVariant(id: variant), using: &rng)
        }
        let other = try #require(cat.variants.last).id
        let history = HatchHistory(pets: [pet(3, colour), pet(1, colour), pet(2, colour)], catalog: catalog)
        #expect(history.repeatsInARow == 2)
        #expect(
            HatchHistory(pets: [pet(1, colour), pet(2, colour), pet(3, other)], catalog: catalog).repeatsInARow == 0)
    }
}
