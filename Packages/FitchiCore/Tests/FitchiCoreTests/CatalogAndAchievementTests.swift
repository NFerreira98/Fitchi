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
            TestSupport.sample("walk-\(day)", .walk, start: install.addingTimeInterval(Double(day) * .day + .hour), minutes: minutes)
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
        #expect(unlocked.map(\.id) == ["streak-3"])
    }
}
