import Foundation
import Testing

@testable import FitchiCore

@Suite("Neglect warnings")
struct NeglectWarningTests {
    let noon = TestSupport.date(hour: 12)

    @Test func warnsWhenEachStageBeginsMatchingTheCondition() throws {
        let context = TestSupport.context()
        let pet = TestSupport.pet(at: noon)
        let warnings = NeglectWarnings.plan(for: pet, after: noon, in: context)
        #expect(warnings.map(\.condition) == [.sick, .packing, .ranAway])
        for warning in warnings {
            // The flat test config has no night hours, so nothing gets moved to the morning.
            #expect(pet.condition(at: warning.date, in: context) == warning.condition)
            #expect(pet.condition(at: warning.date - 120, in: context) != warning.condition)
        }
    }

    @Test func onlyLaterStagesOnceNeglectHasBegun() throws {
        let context = TestSupport.context()
        let pet = TestSupport.pet(at: noon)
        let sick = try #require(NeglectWarnings.plan(for: pet, after: noon, in: context).first?.date)
        let later = NeglectWarnings.plan(for: pet, after: sick + 60, in: context)
        #expect(later.map(\.condition) == [.packing, .ranAway])
        let gone = try #require(later.last?.date)
        #expect(NeglectWarnings.plan(for: pet, after: gone + 60, in: context).isEmpty)
    }

    @Test func restingPetsAndNightTimesAreHandled() {
        let context = TestSupport.context(.v1)
        #expect(NeglectWarnings.plan(for: TestSupport.pet(at: noon, active: false), after: noon, in: context).isEmpty)
        let warnings = NeglectWarnings.plan(for: TestSupport.pet(at: noon), after: noon, in: context)
        #expect(warnings.count == 3)
        #expect(warnings.allSatisfy { !context.isNight($0.date) })
    }

    @Test func careMovesTheWarningsLater() throws {
        let context = TestSupport.context()
        let fed = TestSupport.pet(at: noon + .day)
        let neglected = TestSupport.pet(at: noon)
        let before = try #require(NeglectWarnings.plan(for: neglected, after: noon + .day, in: context).first)
        let after = try #require(NeglectWarnings.plan(for: fed, after: noon + .day, in: context).first)
        #expect(after.date > before.date)
    }
}
