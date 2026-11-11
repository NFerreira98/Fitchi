import Foundation
import Testing

@testable import FitchiCore

@Suite("Stat decay")
struct DecayTests {
    let start = TestSupport.date()

    @Test func decaysLinearlyByBaseRateForAveragePet() {
        // pickyEater has no decay modifiers and average traits are 1.0x, so hunger loses 2.1/h.
        let pet = TestSupport.pet(at: start)
        let value = pet.value(of: .hunger, at: start.addingTimeInterval(10 * .hour), in: TestSupport.context())
        #expect(abs(value - 79) < 0.001)
    }

    @Test func neverDropsBelowZero() {
        let pet = TestSupport.pet(at: start)
        #expect(pet.value(of: .hunger, at: start.addingTimeInterval(30 * .day), in: TestSupport.context()) == 0)
    }

    @Test func nightHoursDecaySlower() {
        let pet = TestSupport.pet(at: TestSupport.date(hour: 22))
        let context = TestSupport.context(.v1)  // nightFactor 0.3 between 22:00 and 07:00
        let morning = TestSupport.date(2026, 1, 6, hour: 7)
        // 9 night hours × 0.3 = 2.7 effective hours.
        #expect(abs(context.effectiveHours(from: pet.hatchedAt, to: morning) - 2.7) < 0.001)
        #expect(abs(pet.value(of: .hunger, at: morning, in: context) - (100 - 2.1 * 2.7)) < 0.001)
    }

    @Test func vacationFreezesDecay() {
        let pet = TestSupport.pet(at: start)
        let vacation = DateInterval(start: start.addingTimeInterval(2 * .hour), duration: 3 * .day)
        let context = TestSupport.context(vacations: [vacation])
        let end = vacation.end.addingTimeInterval(1 * .hour)
        // Only 2h before + 1h after the vacation count.
        #expect(abs(pet.value(of: .hunger, at: end, in: context) - (100 - 2.1 * 3)) < 0.001)
    }

    @Test func restingPetsDecaySlower() {
        let active = TestSupport.pet(at: start, active: true)
        let resting = TestSupport.pet(at: start, active: false)
        let later = start.addingTimeInterval(10 * .hour)
        let context = TestSupport.context()
        let activeLoss = 100 - active.value(of: .hunger, at: later, in: context)
        let restingLoss = 100 - resting.value(of: .hunger, at: later, in: context)
        #expect(abs(restingLoss - activeLoss * DecayConfig.v1.restingFactor) < 0.001)
    }

    @Test func traitsAndPersonalityChangeRates() {
        let hungryTraits = PetTraits(appetite: 1, playfulness: 0.5, stamina: 0.5, tidiness: 0.5)
        var glutton = Pet(name: "G", speciesID: "dog", traits: hungryTraits, personality: .glutton, hatchedAt: start)
        glutton.setActive(true, at: start, in: TestSupport.context())
        // 2.1 × 1.3 (max appetite) × 1.25 (glutton)
        #expect(abs(glutton.decayRate(for: .hunger, config: .v1) - 2.1 * 1.3 * 1.25) < 0.001)
    }

    @Test func swappingActivePetReanchorsStats() throws {
        let context = TestSupport.context()
        var roster = PetRoster()
        let first = TestSupport.pet(at: start)
        let second = TestSupport.pet(at: start)
        roster.add(first, at: start, in: context)
        roster.add(second, at: start, in: context)
        #expect(roster.activePet?.id == first.id)

        let swapTime = start.addingTimeInterval(10 * .hour)
        try roster.setActive(second.id, at: swapTime, in: context)
        #expect(roster.activePet?.id == second.id)

        // First pet: 10h active decay, then resting decay afterwards.
        let resting = try #require(roster[first.id])
        let later = swapTime.addingTimeInterval(4 * .hour)
        let expected = 100 - 2.1 * 10 - 2.1 * DecayConfig.v1.restingFactor * 4
        #expect(abs(resting.value(of: .hunger, at: later, in: context) - expected) < 0.001)
    }
}
