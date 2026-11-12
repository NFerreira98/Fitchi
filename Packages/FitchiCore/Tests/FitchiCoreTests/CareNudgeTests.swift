import Foundation
import Testing

@testable import FitchiCore

@Suite("Care nudges")
struct CareNudgeTests {
    let noon = TestSupport.date(hour: 12)

    @Test func findsTheMomentAStatGetsLow() throws {
        let context = TestSupport.context()
        let pet = TestSupport.pet(at: noon)
        let date = try #require(
            pet.date(when: .hunger, fallsTo: 35, after: noon, within: 3 * .day, in: context))
        #expect(abs(pet.value(of: .hunger, at: date, in: context) - 35) < 0.01)
        #expect(pet.value(of: .hunger, at: date - 60, in: context) > 35)
        // Already low, or not low within the horizon: nothing to predict.
        #expect(pet.date(when: .hunger, fallsTo: 35, after: date + 60, within: .day, in: context) == nil)
        #expect(pet.date(when: .hunger, fallsTo: 35, after: noon, within: 60, in: context) == nil)
    }

    @Test func everyNeedIsPlannedInOrderAndNeverAtNight() {
        let context = TestSupport.context(.v1)
        let pet = TestSupport.pet(at: noon)
        let nudges = CareNudges.plan(for: pet, after: noon, in: context)
        let dueWithinHorizon = Stat.allCases.filter {
            pet.date(when: $0, fallsTo: PetMood.needThreshold, after: noon, within: CareNudges.horizon, in: context)
                != nil
        }
        #expect(dueWithinHorizon.contains(.hunger))
        #expect(Set(nudges.flatMap(\.stats)) == Set(dueWithinHorizon))
        #expect(nudges.map(\.date) == nudges.map(\.date).sorted())
        #expect(nudges.allSatisfy { !context.isNight($0.date) && $0.date > noon })
    }

    @Test func nightNeedsWaitForTheMorning() {
        let context = TestSupport.context(.v1)
        let lateNight = TestSupport.date(2026, 1, 6, hour: 2)
        #expect(CareNudges.outsideQuietHours(lateNight, in: context) == TestSupport.date(2026, 1, 6, hour: 7))
        let evening = TestSupport.date(2026, 1, 5, hour: 23)
        #expect(CareNudges.outsideQuietHours(evening, in: context) == TestSupport.date(2026, 1, 6, hour: 7))
        #expect(CareNudges.outsideQuietHours(noon, in: context) == noon)
    }

    @Test func needsDueTogetherBecomeOneReminder() {
        // Everything at 40 with flat decay: each stat crosses 35 within a few hours, close together.
        let context = TestSupport.context()
        let pet = TestSupport.pet(at: noon, initialValue: 36)
        let nudges = CareNudges.plan(for: pet, after: noon, in: context)
        #expect(nudges.count < Stat.allCases.count)
        #expect(nudges.flatMap(\.stats).count == Stat.allCases.count)
        for nudge in nudges {
            #expect(nudge.stats.count == Set(nudge.stats).count)
        }
    }

    @Test func restingPetsGetNoReminders() {
        let pet = TestSupport.pet(at: noon, active: false)
        #expect(CareNudges.plan(for: pet, after: noon, in: TestSupport.context()).isEmpty)
    }
}
