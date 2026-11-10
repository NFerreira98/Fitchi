import Foundation
import Testing
@testable import FitchiCore

@Suite("Starter egg")
struct StarterEggTests {
    let rules = HatchRules.v1
    let calendar = TestSupport.calendar

    @Test(arguments: [
        (20, TestSupport.date(2026, 1, 6, hour: 7)),  // evening → next morning
        (6, TestSupport.date(2026, 1, 6, hour: 7)),  // 06:00 → not 1h later, next day
        (0, TestSupport.date(2026, 1, 5, hour: 7)),  // just after midnight → same morning (7h)
    ])
    func fallbackIsTheNextMorning(grantedHour: Int, expected: Date) {
        let egg = StarterEgg(grantedAt: TestSupport.date(hour: grantedHour))
        #expect(rules.fallbackDate(for: egg, calendar: calendar) == expected)
    }

    @Test func fiveActiveMinutesAfterGrantingHatches() {
        let granted = TestSupport.date(hour: 8)
        let egg = StarterEgg(grantedAt: granted)
        let samples = [
            TestSupport.sample("before", .walk, start: granted - 360, minutes: 8),  // 2 of its 8 min are after granting
            TestSupport.sample("typed", .run, start: granted + 60, minutes: 30, userEntered: true),
            TestSupport.sample("p", .passive, start: granted + 900, minutes: 2),
        ]
        let early = rules.progress(for: egg, samples: Array(samples.prefix(2)), at: granted + 3600, calendar: calendar)
        #expect(early.activeMinutes == 2)
        #expect(early.minutesRemaining == 3)
        #expect(!early.isReady)

        let later = rules.progress(for: egg, samples: samples + [
            TestSupport.sample("p2", .passive, start: granted + 1200, minutes: 1),
        ], at: granted + 3600, calendar: calendar)
        #expect(later.activeMinutes == 5)
        #expect(later.isReady)
    }

    @Test func readyByFallbackWithoutActivityButNeverOnceHatched() {
        var egg = StarterEgg(grantedAt: TestSupport.date(hour: 20))
        let morning = TestSupport.date(2026, 1, 6, hour: 7)
        #expect(rules.progress(for: egg, samples: [], at: morning - 60, calendar: calendar).isReady == false)
        #expect(rules.progress(for: egg, samples: [], at: morning, calendar: calendar).isReady)
        egg.hatchedPetID = UUID()
        #expect(rules.progress(for: egg, samples: [], at: morning, calendar: calendar).isReady == false)
    }

    @Test func starterHatchesCommonWithFullStatsAndADefaultName() throws {
        var rng = SeededRandom(seed: 7)
        let pet = try Hatchery.hatchStarter(from: TestSupport.catalog, at: TestSupport.date(), using: &rng)
        let species = try #require(TestSupport.catalog.species(id: pet.speciesID))
        #expect(species.rarity == .common)
        #expect(species.defaultNames.contains(pet.name))
        #expect(species.emoji != nil)
        #expect(pet.value(of: .hunger, at: TestSupport.date(), in: TestSupport.context()) == 100)
    }

    @Test func namesAreTrimmedAndCapped() {
        #expect(PetName.sanitized("  Sir   Barks  ") == "Sir Barks")
        #expect(PetName.sanitized("   ") == nil)
        #expect(PetName.sanitized(String(repeating: "a", count: 40))?.count == PetName.maxLength)
    }
}
