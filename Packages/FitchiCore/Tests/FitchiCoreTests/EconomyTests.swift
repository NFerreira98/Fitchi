import Foundation
import Testing
@testable import FitchiCore

@Suite("Wallet, shop & eggs")
struct EconomyTests {
    let now = TestSupport.date()
    let catalog = TestSupport.catalog

    @Test func balanceIsEarningsPlusTransactions() {
        var wallet = Wallet(earnings: [Earning(sourceID: "a", day: now, amount: 50, rulesVersion: 1)])
        wallet.record(.welcomeBonus(100, at: now))
        wallet.record(.purchase(itemID: "kibble", price: 6, at: now))
        #expect(wallet.balance == 144)
        #expect(wallet.totalEarned == 150)
    }

    @Test func welcomeBonusAndAchievementRewardsAreOneTime() throws {
        var wallet = Wallet()
        wallet.record(.welcomeBonus(100, at: now))
        wallet.record(.welcomeBonus(100, at: now))
        let achievement = try #require(catalog.achievements.first)
        wallet.record(.achievementReward(achievement, at: now))
        wallet.record(.achievementReward(achievement, at: now))
        #expect(wallet.balance == 100 + achievement.reward)
    }

    @Test func buyingConsumablesStacksAndSpends() throws {
        var wallet = Wallet(transactions: [.welcomeBonus(100, at: now)])
        var inventory = Inventory()
        let kibble = try #require(catalog.item(id: "kibble"))
        try Shop.buy(kibble, wallet: &wallet, inventory: &inventory, at: now)
        try Shop.buy(kibble, wallet: &wallet, inventory: &inventory, at: now)
        #expect(inventory.count(of: "kibble") == 2)
        #expect(wallet.balance == 100 - 2 * kibble.price)
    }

    @Test func cannotOverspendOrRebuyCosmetics() throws {
        var wallet = Wallet(transactions: [.welcomeBonus(100, at: now)])
        var inventory = Inventory()
        let cape = try #require(catalog.item(id: "hero-cape"))
        #expect(throws: ShopError.insufficientFunds(price: cape.price, balance: 100)) {
            try Shop.buy(cape, wallet: &wallet, inventory: &inventory, at: now)
        }
        wallet.record(.init(id: "gift", kind: .adjustment(reason: "test"), amount: 1_000, date: now))
        try Shop.buy(cape, wallet: &wallet, inventory: &inventory, at: now)
        #expect(throws: ShopError.alreadyOwned) {
            try Shop.buy(cape, wallet: &wallet, inventory: &inventory, at: now)
        }
    }

    @Test func starterIsAlwaysCommonAndTraitsStayInRange() throws {
        var rng = SeededRandom(seed: 42)
        var seen = Set<String>()
        for _ in 0..<200 {
            let pet = try Hatchery.hatchStarter(from: catalog, at: now, using: &rng)
            let species = try #require(catalog.species(id: pet.speciesID))
            #expect(species.rarity == .common)
            #expect(species.traitRanges.contains(pet.traits))
            seen.insert(species.id)
        }
        #expect(seen == ["dog", "cat", "axolotl"])
    }

    @Test func hatchingIsDeterministicForASeed() throws {
        let egg = try #require(catalog.egg(id: "sparkle-egg"))
        var first = SeededRandom(seed: 7)
        var second = SeededRandom(seed: 7)
        let one = try Hatchery.hatch(egg, from: catalog, at: now, using: &first)
        let two = try Hatchery.hatch(egg, from: catalog, at: now, using: &second)
        #expect(one.speciesID == two.speciesID && one.traits == two.traits && one.personality == two.personality)
    }

    @Test func eggOddsRoughlyMatchTheirWeights() throws {
        let egg = try #require(catalog.egg(id: "meadow-egg"))
        var rng = SeededRandom(seed: 1)
        var counts: [Rarity: Int] = [:]
        for _ in 0..<5_000 {
            let pet = try Hatchery.hatch(egg, from: catalog, at: now, using: &rng)
            counts[try #require(catalog.species(id: pet.speciesID)).rarity, default: 0] += 1
        }
        let commonShare = Double(counts[.common, default: 0]) / 5_000
        #expect(abs(commonShare - 0.8) < 0.03)
        #expect(counts[.epic] == nil && counts[.legendary] == nil)
    }

    @Test func buyingAnEggSpendsPepAndHatchesAPet() throws {
        let egg = try #require(catalog.egg(id: "meadow-egg"))
        var wallet = Wallet(transactions: [.welcomeBonus(700, at: now)])
        var rng = SeededRandom(seed: 3)
        let pet = try Shop.buyEgg(egg, from: catalog, wallet: &wallet, at: now, using: &rng)
        #expect(wallet.balance == 100)
        #expect(catalog.species(id: pet.speciesID) != nil)
    }

    @Test func eggDisplayOddsArePercentages() throws {
        let egg = try #require(catalog.egg(id: "golden-egg"))
        #expect(abs(egg.displayOdds.values.reduce(0, +) - 100) < 0.0001)
    }
}
