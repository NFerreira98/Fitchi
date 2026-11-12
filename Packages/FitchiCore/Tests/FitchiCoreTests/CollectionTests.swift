import Foundation
import Testing

@testable import FitchiCore

@Suite("Collection book")
struct CollectionTests {
    /// The real catalog, except the bunny has no colour variants (so both kinds are covered).
    let catalog: Catalog = {
        var catalog = TestSupport.catalog
        if let index = catalog.species.firstIndex(where: { $0.id == "bunny" }) {
            catalog.species[index].variants = []
            catalog.species[index].shiny = nil
        }
        return catalog
    }()
    let start = TestSupport.date()

    func pet(_ speciesID: String, variant: PetVariant?, at date: Date) -> Pet {
        Pet(
            name: "Test", speciesID: speciesID, traits: TestSupport.averageTraits, personality: .easygoing,
            hatchedAt: date, variant: variant)
    }

    @Test func listsEveryColouringAndShinyCommonsFirst() throws {
        let book = CollectionBook(catalog: catalog, pets: [])
        #expect(book.foundCount == 0)
        let expected = catalog.species.reduce(0) { total, species in
            total + max(species.variants.count, 1) + (species.shiny == nil ? 0 : 1)
        }
        #expect(book.totalCount == expected)
        #expect(book.species.map(\.species.rarity) == book.species.map(\.species.rarity).sorted())
        let cat = try #require(book.species.first { $0.id == "cat" })
        #expect(cat.entries.last?.isShiny == true)
        #expect(cat.entries.dropLast().allSatisfy { !$0.isShiny })
        let bunny = try #require(book.species.first { $0.id == "bunny" })
        #expect(bunny.entries.count == 1)
        #expect(bunny.entries.first?.variantID == nil)
    }

    @Test func petsFillInTheirEntriesWithTheFirstFindDate() throws {
        let ginger = PetVariant(id: "ginger")
        let pets = [
            pet("cat", variant: ginger, at: start + 100),
            pet("cat", variant: ginger, at: start),
            pet("cat", variant: PetVariant(id: "shiny-sugar", isShiny: true), at: start),
            pet("bunny", variant: nil, at: start),
            // Before variants existed: counts as the species' first colouring.
            pet("dog", variant: nil, at: start),
        ]
        let book = CollectionBook(catalog: catalog, pets: pets)
        let entries = Dictionary(uniqueKeysWithValues: book.entries.map { ($0.id, $0) })
        #expect(entries["cat/ginger"]?.foundAt == start)
        #expect(entries["cat/shiny-sugar"]?.isFound == true)
        #expect(entries["bunny/-"]?.isFound == true)
        let firstDog = try #require(catalog.species(id: "dog")?.variants.first?.id)
        #expect(entries["dog/\(firstDog)"]?.isFound == true)
        #expect(book.foundCount == 4)
        #expect(book.shiniesFound == 1)
        #expect(book.species.first { $0.id == "cat" }?.isDiscovered == true)
        #expect(book.species.first { $0.id == "penguin" }?.isDiscovered == false)
    }
}

@Suite("Backdrops")
struct BackdropTests {
    @Test func buyingThePondLetsYouUseIt() throws {
        let pond = try #require(TestSupport.catalog.item(id: "backdrop-pond"))
        #expect(pond.category == .backdrop)
        var inventory = Inventory()
        #expect(inventory.activeBackdropID == Catalog.defaultBackdropID)
        let lockedChoice = inventory.selectBackdrop(pond.id)
        #expect(!lockedChoice)

        var wallet = Wallet(transactions: [.welcomeBonus(1000, at: TestSupport.date())])
        try Shop.buy(pond, wallet: &wallet, inventory: &inventory, at: TestSupport.date())
        #expect(throws: ShopError.alreadyOwned) {
            try Shop.buy(pond, wallet: &wallet, inventory: &inventory, at: TestSupport.date())
        }
        let ownedChoice = inventory.selectBackdrop(pond.id)
        #expect(ownedChoice)
        #expect(inventory.activeBackdropID == pond.id)
        let backToDefault = inventory.selectBackdrop(Catalog.defaultBackdropID)
        #expect(backToDefault)
    }

    @Test func inventoriesFromBeforeBackdropsStillLoad() throws {
        let old = #"{"consumables":{"kibble":2},"ownedItemIDs":["party-hat"],"activeArtStyleID":"classic"}"#
        let inventory = try JSONDecoder().decode(Inventory.self, from: Data(old.utf8))
        #expect(inventory.count(of: "kibble") == 2)
        #expect(inventory.activeBackdropID == Catalog.defaultBackdropID)
        var merged = inventory
        merged.grantOwnership(of: ["backdrop-pond"])
        #expect(merged.owns("backdrop-pond") && merged.owns("party-hat"))
    }
}
