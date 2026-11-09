import Foundation
import Testing
@testable import FitchiCore

@Suite("Care, wardrobe & comeback")
struct CareTests {
    let start = TestSupport.date()
    let context = TestSupport.context()
    let catalog = TestSupport.catalog

    func item(_ id: String) throws -> ShopItem { try #require(catalog.item(id: id)) }
    func species(_ id: String) throws -> Species { try #require(catalog.species(id: id)) }

    @Test func feedingRaisesHungerAndConsumesItem() throws {
        var pet = TestSupport.pet(personality: .easygoing, at: start, initialValue: 40)
        var inventory = Inventory(consumables: ["kibble": 2])
        try Care.use(try item("kibble"), on: &pet, species: try species("cat"), inventory: &inventory, at: start, in: context)
        #expect(pet.value(of: .hunger, at: start, in: context) == 75)
        #expect(inventory.count(of: "kibble") == 1)
    }

    @Test func statsCapAt100() throws {
        var pet = TestSupport.pet(personality: .easygoing, at: start, initialValue: 90)
        var inventory = Inventory(consumables: ["kibble": 1])
        try Care.use(try item("kibble"), on: &pet, species: try species("cat"), inventory: &inventory, at: start, in: context)
        #expect(pet.value(of: .hunger, at: start, in: context) == 100)
    }

    @Test func favoritesRestoreMoreAndNegativeEffectsAreNotScaled() throws {
        var pet = TestSupport.pet(personality: .easygoing, at: start, initialValue: 40)
        var inventory = Inventory(consumables: ["tennis-ball": 1])
        try Care.use(try item("tennis-ball"), on: &pet, species: try species("dog"), inventory: &inventory, at: start, in: context)
        #expect(pet.value(of: .happiness, at: start, in: context) == 40 + 35 * 1.25)
        #expect(pet.value(of: .energy, at: start, in: context) == 35)
    }

    @Test func pickyEatersDislikeNonFavorites() throws {
        var pet = TestSupport.pet(personality: .pickyEater, at: start, initialValue: 40)
        var inventory = Inventory(consumables: ["kibble": 1])
        try Care.use(try item("kibble"), on: &pet, species: try species("dog"), inventory: &inventory, at: start, in: context)
        #expect(pet.value(of: .hunger, at: start, in: context) == 40 + 35 * 0.75)
    }

    @Test func cannotUseItemsYouDoNotHave() throws {
        var pet = TestSupport.pet(at: start)
        var inventory = Inventory()
        #expect(throws: CareError.noneLeft) {
            try Care.use(try item("kibble"), on: &pet, species: try species("dog"), inventory: &inventory, at: start, in: context)
        }
    }

    @Test func ranAwayPetsCannotBeCaredForUntilComebackQuestIsDone() throws {
        var pet = TestSupport.pet(at: start)
        let gone = start.addingTimeInterval(30 * .day)
        var inventory = Inventory(consumables: ["kibble": 1])
        #expect(pet.condition(at: gone, in: context) == .ranAway)
        #expect(throws: CareError.petRanAway) {
            try Care.use(try item("kibble"), on: &pet, species: try species("dog"), inventory: &inventory, at: gone, in: context)
        }
        #expect(inventory.count(of: "kibble") == 1)

        let quest = ComebackQuest.v1
        let walk = TestSupport.sample("w1", .walk, start: gone, minutes: 40)
        #expect(throws: ComebackError.questIncomplete(minutesDone: 40, minutesNeeded: 60)) {
            try quest.bringHome(&pet, samples: [walk], at: gone.addingTimeInterval(.hour), in: context)
        }
        let run = TestSupport.sample("r1", .run, start: gone.addingTimeInterval(.hour), minutes: 25)
        let home = gone.addingTimeInterval(2 * .hour)
        try quest.bringHome(&pet, samples: [walk, run], at: home, in: context)
        #expect(pet.condition(at: home, in: context) == .content)
    }

    @Test func activityBeforeRunningAwayDoesNotCountTowardComeback() throws {
        let pet = TestSupport.pet(at: start)
        let gone = start.addingTimeInterval(30 * .day)
        let oldRun = TestSupport.sample("old", .run, start: start, minutes: 120)
        #expect(ComebackQuest.v1.progress(for: pet, samples: [oldRun], at: gone, in: context) == 0)
    }

    @Test func equippingRequiresOwnershipAndUsesSlot() throws {
        var pet = TestSupport.pet(at: start)
        let hat = try item("party-hat")
        #expect(throws: CareError.notOwned) { try Wardrobe.equip(hat, on: &pet, inventory: Inventory()) }
        try Wardrobe.equip(hat, on: &pet, inventory: Inventory(ownedItemIDs: ["party-hat"]))
        #expect(pet.equipped[.head] == "party-hat")
        #expect(throws: CareError.notAnAccessory) {
            try Wardrobe.equip(try item("kibble"), on: &pet, inventory: Inventory(consumables: ["kibble": 1]))
        }
    }
}
