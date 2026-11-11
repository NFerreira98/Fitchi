import Foundation
import Testing

@testable import FitchiCore

@Suite("Pet condition & neglect")
struct ConditionTests {
    let start = TestSupport.date()
    let context = TestSupport.context()

    @Test func moodFollowsWellbeing() {
        let pet = TestSupport.pet(at: start)
        #expect(pet.condition(at: start, in: context) == .thriving)
        #expect(TestSupport.pet(at: start, initialValue: 50).condition(at: start, in: context) == .content)
        #expect(TestSupport.pet(at: start, initialValue: 30).condition(at: start, in: context) == .sad)
    }

    @Test func neglectEscalatesThenPetRunsAway() throws {
        let pet = TestSupport.pet(at: start)
        let neglectStart = try #require(pet.neglectStart(at: start.addingTimeInterval(30 * .day), in: context))
        #expect(neglectStart > start)

        func condition(after offset: TimeInterval) -> PetCondition {
            pet.condition(at: neglectStart.addingTimeInterval(offset), in: context)
        }
        #expect(condition(after: 1 * .hour) == .sad)
        #expect(condition(after: 2 * .day + 1) == .sick)
        #expect(condition(after: 4 * .day + 1) == .packing)
        #expect(condition(after: 6 * .day + 1) == .ranAway)
        #expect(pet.ranAwayDate(at: neglectStart.addingTimeInterval(7 * .day), in: context) != nil)
    }

    @Test func runningAwayTakesAtLeastAWeekFromFullStatsWithRealNights() throws {
        let realContext = TestSupport.context(.v1)
        let pet = TestSupport.pet(at: start)
        let leftAt = try #require(pet.ranAwayDate(at: start.addingTimeInterval(60 * .day), in: realContext))
        #expect(leftAt.timeIntervalSince(start) >= 7 * .day)
    }

    @Test func vacationPausesTheNeglectClock() throws {
        let pet = TestSupport.pet(at: start)
        let neglectStart = try #require(pet.neglectStart(at: start.addingTimeInterval(30 * .day), in: context))
        let vacation = DateInterval(start: neglectStart.addingTimeInterval(.hour), duration: 10 * .day)
        let onVacation = TestSupport.context(vacations: [vacation])
        // 7 wall-clock days into neglect, but most of it was vacation: still just sad.
        #expect(pet.condition(at: neglectStart.addingTimeInterval(7 * .day), in: onVacation) == .sad)
    }
}
