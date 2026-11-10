import Foundation
import Testing
@testable import FitchiCore

@Suite("Quick care")
struct QuickCareTests {
    let catalog = TestSupport.catalog
    let now = TestSupport.date()

    func hungryPet(_ personality: Personality = .easygoing) -> Pet {
        var pet = TestSupport.pet(personality: personality, at: now, initialValue: 40)
        pet.setActive(true, at: now, in: TestSupport.context())
        return pet
    }

    func perform(
        _ action: CareAction,
        pet: inout Pet,
        wallet: inout Wallet,
        inventory: inout Inventory
    ) throws(QuickCareError) -> CareOutcome {
        try QuickCare.perform(
            action, on: &pet, catalog: catalog,
            wallet: &wallet, inventory: &inventory, at: now, in: TestSupport.context()
        )
    }

    @Test func feedingBuysTheFavouriteWhenAffordableAndSpendsPep() throws {
        var pet = hungryPet()
        var wallet = Wallet(transactions: [.welcomeBonus(100, at: now)])
        var inventory = Inventory()
        let outcome = try perform(.feed, pet: &pet, wallet: &wallet, inventory: &inventory)
        #expect(outcome.itemID == "bone-biscuit")
        #expect(outcome.reaction == .loved)
        #expect(wallet.balance == 90)
        #expect(inventory.count(of: "bone-biscuit") == 0)
        #expect((outcome.changes[.hunger] ?? 0) > 30)
        #expect(pet.value(of: .hunger, at: now, in: TestSupport.context()) > 70)
    }

    @Test func fallsBackToCheapestThenRefusesWhenBroke() throws {
        var pet = hungryPet()
        var wallet = Wallet(transactions: [.welcomeBonus(7, at: now)])
        var inventory = Inventory()
        let outcome = try perform(.feed, pet: &pet, wallet: &wallet, inventory: &inventory)
        #expect(outcome.itemID == "kibble")
        #expect(wallet.balance == 1)

        let before = pet
        #expect(throws: QuickCareError.cantAfford(price: 8)) {
            try perform(.play, pet: &pet, wallet: &wallet, inventory: &inventory)
        }
        #expect(pet == before)
        #expect(wallet.balance == 1)
    }

    @Test func usesOwnedItemsBeforeBuying() throws {
        var pet = hungryPet()
        var wallet = Wallet(transactions: [.welcomeBonus(100, at: now)])
        var inventory = Inventory()
        try Shop.buy(try #require(catalog.item(id: "squeaky-toy")), wallet: &wallet, inventory: &inventory, at: now)
        let outcome = try perform(.play, pet: &pet, wallet: &wallet, inventory: &inventory)
        #expect(outcome.itemID == "squeaky-toy")
        #expect(wallet.balance == 88)
    }

    @Test func wontWastePepOnAFullPet() {
        var pet = TestSupport.pet(at: now, initialValue: 100)
        var wallet = Wallet(transactions: [.welcomeBonus(100, at: now)])
        var inventory = Inventory()
        #expect(throws: QuickCareError.alreadySatisfied(.hunger)) {
            try perform(.feed, pet: &pet, wallet: &wallet, inventory: &inventory)
        }
        #expect(wallet.balance == 100)
    }

    @Test func pickyEaterIsMehAboutPlainFood() throws {
        var pet = hungryPet(.pickyEater)
        var wallet = Wallet(transactions: [.welcomeBonus(8, at: now)])  // can't afford the favourite
        var inventory = Inventory()
        let outcome = try perform(.feed, pet: &pet, wallet: &wallet, inventory: &inventory)
        #expect(outcome.itemID == "kibble")
        #expect(outcome.reaction == .meh)
    }
}
