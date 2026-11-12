import Foundation
import Testing

@testable import FitchiCore

@Suite("Catalog content")
struct CatalogTests {
    @Test func shippedContentIsValid() {
        let problems = TestSupport.catalog.validate()
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
    }

    @Test func startersAreDogCatAndAxolotl() {
        let commons = TestSupport.catalog.species.filter { $0.rarity == .common }.map(\.id)
        #expect(Set(commons) == ["dog", "cat", "axolotl"])
    }

    @Test func validationCatchesBrokenContent() {
        let broken = Catalog(
            species: [],
            items: [ShopItem(id: "hat", name: "Hat", category: .accessory, price: 0)],
            eggs: [EggType(id: "egg", name: "Egg", price: 10, odds: [.legendary: 1])],
            achievements: []
        )
        let problems = broken.validate()
        #expect(problems.contains { $0.contains("No common species") })
        #expect(problems.contains { $0.contains("positive price") })
        #expect(problems.contains { $0.contains("no slot") })
        #expect(problems.contains { $0.contains("cannot hatch") })
    }

    @Test func criterionRoundTripsThroughJSON() throws {
        let criterion = Criterion.workouts(kind: .swim, count: 5)
        let data = try JSONEncoder().encode(criterion)
        #expect(try JSONDecoder().decode(Criterion.self, from: data) == criterion)
    }
}

@Suite("Achievements & progress")
struct AchievementTests {
    let install = TestSupport.date(hour: 6)
    let calendar = TestSupport.calendar

    func walks(days: [Int], minutes: Double = 30) -> [ActivitySample] {
        days.map { day in
            TestSupport.sample(
                "walk-\(day)", .walk, start: install.addingTimeInterval(Double(day) * .day + .hour), minutes: minutes)
        }
    }

    @Test func streaksCountConsecutiveActiveDays() {
        let samples = walks(days: [0, 1, 2, 4, 5])
        let progress = PlayerProgress.compute(
            samples: samples, since: install, wallet: Wallet(), petsOwned: 1,
            at: install.addingTimeInterval(5 * .day + 2 * .hour), calendar: calendar
        )
        #expect(progress.longestStreakDays == 3)
        #expect(progress.currentStreakDays == 2)
    }

    @Test func shortDaysDoNotCountTowardStreaks() {
        let progress = PlayerProgress.compute(
            samples: walks(days: [0, 1, 2], minutes: 10), since: install, wallet: Wallet(), petsOwned: 1,
            at: install.addingTimeInterval(3 * .day), calendar: calendar
        )
        #expect(progress.longestStreakDays == 0)
    }

    @Test func unlocksOnlyNewAchievements() {
        let progress = PlayerProgress.compute(
            samples: walks(days: [0, 1, 2]), since: install, wallet: Wallet(), petsOwned: 1,
            at: install.addingTimeInterval(3 * .day), calendar: calendar
        )
        let unlocked = Achievement.newlyUnlocked(
            TestSupport.catalog.achievements, progress: progress, alreadyUnlocked: ["first-steps"]
        )
        // Three active days, and owning a pet earns "New Friend".
        #expect(unlocked.map(\.id) == ["streak-3", "first-friend"])
    }

    @Test func collectingAndTimeTogetherCount() throws {
        let catalog = TestSupport.catalog
        let hatched = TestSupport.date(2026, 1, 1)
        let pets = [
            Pet(
                name: "A", speciesID: "cat", traits: TestSupport.averageTraits, personality: .easygoing,
                hatchedAt: hatched,
                variant: PetVariant(id: "shiny-sugar", isShiny: true)),
            Pet(
                name: "B", speciesID: "penguin", traits: TestSupport.averageTraits, personality: .easygoing,
                hatchedAt: hatched + .day, variant: PetVariant(id: "emperor")),
        ]
        var inventory = Inventory()
        inventory.grantOwnership(of: ["backdrop-pond", "backdrop-forest", "party-hat"])
        let progress = PlayerProgress().including(
            collection: CollectionBook(catalog: catalog, pets: pets), pets: pets, inventory: inventory,
            catalog: catalog,
            at: TestSupport.date(2026, 1, 8), calendar: calendar)
        #expect(progress.petsOwned == 2)
        #expect(progress.collectionFound == 2)
        #expect(progress.shiniesFound == 1)
        #expect(progress.speciesFound == 2)
        #expect(progress.rarestFound == .rare)
        #expect(progress.daysTogether == 7)
        #expect(progress.backdropsOwned == 2)

        let unlocked = Set(
            Achievement.newlyUnlocked(catalog.achievements, progress: progress, alreadyUnlocked: []).map(\.id))
        #expect(unlocked.isSuperset(of: ["first-shiny", "rare-find", "together-7", "decor-1"]))
        #expect(!unlocked.contains("legend") && !unlocked.contains("decor-4"))
        let decor = try #require(catalog.achievements.first { $0.id == "decor-4" })
        #expect(decor.criterion.progress(in: progress) == (2, 4))
    }

    @Test func everyAchievementDecodesAndRoundTrips() throws {
        let achievements = TestSupport.catalog.achievements
        #expect(achievements.count >= 30)
        #expect(Set(achievements.map(\.id)).count == achievements.count)
        #expect(achievements.allSatisfy { $0.reward > 0 && $0.icon != nil })
        let data = try JSONEncoder().encode(achievements)
        #expect(try JSONDecoder().decode([Achievement].self, from: data) == achievements)
    }
}
