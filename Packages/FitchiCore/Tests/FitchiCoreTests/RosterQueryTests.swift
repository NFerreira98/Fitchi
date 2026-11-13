import Foundation
import Testing

@testable import FitchiCore

@Suite("Pets tab: search, filters, sort and groups")
struct RosterQueryTests {
    let catalog = TestSupport.catalog

    func pet(
        _ name: String, _ species: String, _ variant: String? = nil, shiny: Bool = false, day: Int,
        personality: Personality = .easygoing, favorite: Bool = false
    ) -> Pet {
        var pet = Pet(
            name: name, speciesID: species,
            traits: PetTraits(appetite: 0.5, playfulness: 0.5, stamina: 0.5, tidiness: 0.5), personality: personality,
            hatchedAt: TestSupport.date(2026, 3, day), variant: variant.map { PetVariant(id: $0, isShiny: shiny) })
        pet.isFavorite = favorite
        return pet
    }

    var pets: [Pet] {
        [
            pet("Biscuit", "dog", "honey", day: 1),
            pet("Miso", "cat", "ginger", day: 2, personality: .glutton),
            pet("Luna", "cat", "midnight", day: 3, favorite: true),
            pet("Pip", "penguin", "shiny-strawberry", shiny: true, day: 4),
            pet("Ánya", "axolotl", "leucistic", day: 5, personality: .hyper),
        ]
    }

    func names(_ query: RosterQuery) -> [String] { query.apply(to: pets, in: catalog).map(\.name) }

    @Test func newestFirstWithFavouritesOnTop() {
        #expect(names(RosterQuery()) == ["Luna", "Ánya", "Pip", "Miso", "Biscuit"])
        var plain = RosterQuery()
        plain.favouritesFirst = false
        #expect(names(plain) == ["Ánya", "Pip", "Luna", "Miso", "Biscuit"])
    }

    @Test func sorts() {
        var query = RosterQuery()
        query.favouritesFirst = false
        query.sort = .oldest
        #expect(names(query) == ["Biscuit", "Miso", "Luna", "Pip", "Ánya"])
        query.sort = .name
        #expect(names(query) == ["Ánya", "Biscuit", "Luna", "Miso", "Pip"])
        query.sort = .rarity
        #expect(names(query).first == "Pip", "the rare penguin first")
        query.sort = .species
        #expect(names(query) == ["Biscuit", "Luna", "Miso", "Ánya", "Pip"], "catalog order, newest within")
    }

    @Test func searchMatchesNameSpeciesAndColouringIgnoringCaseAndAccents() {
        var query = RosterQuery()
        query.text = "anya"
        #expect(names(query) == ["Ánya"])
        query.text = "CAT"
        #expect(Set(names(query)) == ["Miso", "Luna"])
        query.text = "midnight"
        #expect(names(query) == ["Luna"])
        query.text = "  "
        #expect(names(query).count == 5)
    }

    @Test func filtersCombine() {
        var query = RosterQuery()
        query.species = ["cat"]
        query.kinds = [.special]
        #expect(names(query) == ["Luna"])
        #expect(query.activeFilterCount == 2)
        query.clearFilters()
        query.rarities = [.rare]
        #expect(names(query) == ["Pip"])
        query.rarities = []
        query.kinds = [.shiny]
        #expect(names(query) == ["Pip"])
        query.kinds = []
        query.personalities = [.glutton, .hyper]
        #expect(Set(names(query)) == ["Miso", "Ánya"])
        query.personalities = []
        query.favouritesOnly = true
        #expect(names(query) == ["Luna"])
    }

    @Test func groupsBySpeciesInCatalogOrder() {
        let groups = RosterQuery().grouped(pets, in: catalog)
        #expect(groups.map(\.species.id) == ["dog", "cat", "axolotl", "penguin"])
        #expect(groups[1].pets.map(\.name) == ["Luna", "Miso"])
    }

    @Test func statsAndShelf() throws {
        let stats = RosterStats(pets: pets, catalog: catalog)
        #expect(stats.pets == 5 && stats.speciesOwned == 4 && stats.shinies == 1 && stats.specials == 1)
        #expect(stats.favourites == 1 && stats.newest?.name == "Ánya")
        let cat = try #require(catalog.species(id: "cat"))
        let shelf = ColouringShelf(species: cat, pets: pets)
        #expect(shelf.slots.count == cat.variants.count + 1, "every colouring plus the shiny")
        #expect(shelf.ownedCount == 2)
        #expect(shelf.slots.first { $0.id == "midnight" }?.owned.map(\.name) == ["Luna"])
        #expect(shelf.slots.last?.isShiny == true && shelf.slots.last?.owned.isEmpty == true)
    }

    @Test func favouritesSaveAndOldSavesStillLoad() throws {
        let luna = pets[2]
        let data = try JSONEncoder().encode(luna)
        #expect(try JSONDecoder().decode(Pet.self, from: data).isFavorite)
        // A save from before favourites has no such key.
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(pets[0])) as? [String: Any])
        json["favorite"] = nil
        let old = try JSONDecoder().decode(Pet.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(!old.isFavorite)
    }
}
