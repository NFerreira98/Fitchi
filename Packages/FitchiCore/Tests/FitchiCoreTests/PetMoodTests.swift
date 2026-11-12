import Foundation
import Testing

@testable import FitchiCore

@Suite("Pet mood")
struct PetMoodTests {
    let full: [Stat: Double] = [.hunger: 100, .happiness: 100, .energy: 100, .cleanliness: 100]

    @Test func lowStatsShowAsNeeds() {
        var values = full
        values[.hunger] = 30
        values[.cleanliness] = 35
        let mood = PetMood(values: values, condition: .content, isNight: false)
        #expect(mood.isHungry)
        #expect(mood.isDirty)
        #expect(!mood.isBored)
        #expect(!mood.isTired)
        #expect(!mood.isAsleep)
    }

    @Test func sleepsAtNightOrWhenExhausted() {
        #expect(PetMood(values: full, condition: .thriving, isNight: true).isAsleep)
        var drained = full
        drained[.energy] = 8
        let mood = PetMood(values: drained, condition: .content, isNight: false)
        #expect(mood.isAsleep)
        #expect(mood.isTired)
        #expect(!PetMood(values: full, condition: .ranAway, isNight: true).isAsleep)
    }

    @Test func petMoodUsesTheDecayClock() {
        let context = TestSupport.context()
        let pet = TestSupport.pet(at: TestSupport.date(hour: 12))
        let fresh = pet.mood(at: TestSupport.date(hour: 12), in: context)
        #expect(fresh == PetMood(condition: fresh.condition))
        #expect(pet.mood(at: TestSupport.date(hour: 23), in: context).isAsleep)
        #expect(PetMood(condition: .sick).isDown)
    }
}
