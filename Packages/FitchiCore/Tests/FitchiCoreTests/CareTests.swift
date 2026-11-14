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
        try Care.use(
            try item("kibble"), on: &pet, species: try species("cat"), inventory: &inventory, at: start, in: context)
        #expect(pet.value(of: .hunger, at: start, in: context) == 75)
        #expect(inventory.count(of: "kibble") == 1)
    }

    @Test func statsCapAt100() throws {
        var pet = TestSupport.pet(personality: .easygoing, at: start, initialValue: 90)
        var inventory = Inventory(consumables: ["kibble": 1])
        try Care.use(
            try item("kibble"), on: &pet, species: try species("cat"), inventory: &inventory, at: start, in: context)
        #expect(pet.value(of: .hunger, at: start, in: context) == 100)
    }

    @Test func favoritesRestoreMoreAndNegativeEffectsAreNotScaled() throws {
        var pet = TestSupport.pet(personality: .easygoing, at: start, initialValue: 40)
        var inventory = Inventory(consumables: ["tennis-ball": 1])
        try Care.use(
            try item("tennis-ball"), on: &pet, species: try species("dog"), inventory: &inventory, at: start,
            in: context)
        #expect(pet.value(of: .happiness, at: start, in: context) == 40 + 35 * 1.25)
        #expect(pet.value(of: .energy, at: start, in: context) == 35)
    }

    @Test func pickyEatersDislikeNonFavorites() throws {
        var pet = TestSupport.pet(personality: .pickyEater, at: start, initialValue: 40)
        var inventory = Inventory(consumables: ["kibble": 1])
        try Care.use(
            try item("kibble"), on: &pet, species: try species("dog"), inventory: &inventory, at: start, in: context)
        #expect(pet.value(of: .hunger, at: start, in: context) == 40 + 35 * 0.75)
    }

    @Test func cannotUseItemsYouDoNotHave() throws {
        var pet = TestSupport.pet(at: start)
        var inventory = Inventory()
        #expect(throws: CareError.noneLeft) {
            try Care.use(
                try item("kibble"), on: &pet, species: try species("dog"), inventory: &inventory, at: start, in: context
            )
        }
    }

    @Test func ranAwayPetsCannotBeCaredForUntilComebackQuestIsDone() throws {
        var pet = TestSupport.pet(at: start)
        let gone = start.addingTimeInterval(30 * .day)
        var inventory = Inventory(consumables: ["kibble": 1])
        #expect(pet.condition(at: gone, in: context) == .ranAway)
        #expect(throws: CareError.petRanAway) {
            try Care.use(
                try item("kibble"), on: &pet, species: try species("dog"), inventory: &inventory, at: gone, in: context)
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
        #expect(ComebackQuest.v1.progress(for: pet, samples: [oldRun], at: gone, in: context)?.activeMinutes == 0)
        #expect(ComebackQuest.v1.progress(for: pet, samples: [oldRun], at: start, in: context) == nil)
    }

    @Test func everydayStepsBringAPetHomeWithoutAWatch() throws {
        var pet = TestSupport.pet(at: start)
        let gone = start.addingTimeInterval(30 * .day)
        let quest = ComebackQuest.v1
        let leftAt = try #require(pet.ranAwayDate(at: gone, in: context))
        // An iPhone-only player: just hourly step totals, 6,000 steps = 60 minutes.
        let hours = (0..<3).map { hour in
            StepCount(
                start: gone.addingTimeInterval(Double(hour) * .hour),
                end: gone.addingTimeInterval(Double(hour + 1) * .hour), steps: 1_500)
        }
        let before = StepCount(start: leftAt.addingTimeInterval(-.hour), end: leftAt, steps: 9_000)
        let midway = try #require(quest.progress(for: pet, samples: [], steps: [before] + hours, at: gone, in: context))
        #expect(midway.activeMinutes == 45)
        #expect(midway.minutesRemaining == 15)
        #expect(midway.stepsRemaining == 1_500)
        #expect(!midway.isComplete)

        let more = StepCount(
            start: gone.addingTimeInterval(3 * .hour), end: gone.addingTimeInterval(4 * .hour), steps: 1_500)
        let home = gone.addingTimeInterval(5 * .hour)
        try quest.bringHome(&pet, samples: [], steps: hours + [more], at: home, in: context)
        #expect(pet.value(of: .hunger, at: home, in: context) == quest.returnValue)
        #expect(pet.condition(at: home, in: context) == .content)
    }

    @Test func aWorkoutUnderwayWhenThePetLeftCountsFromThenOn() throws {
        let pet = TestSupport.pet(at: start)
        let gone = start.addingTimeInterval(30 * .day)
        let leftAt = try #require(pet.ranAwayDate(at: gone, in: context))
        let run = TestSupport.sample("r", .run, start: leftAt.addingTimeInterval(-20 * 60), minutes: 50)
        let manual = TestSupport.sample("m", .walk, start: leftAt, minutes: 90, userEntered: true)
        let progress = ComebackQuest.v1.progress(for: pet, samples: [run, manual], at: gone, in: context)
        #expect(progress.map { ($0.activeMinutes * 10).rounded() / 10 } == 30)
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
