import Foundation
import Testing

@testable import FitchiCore

@Suite("Everyday steps")
struct StepsTests {
    let calendar = TestSupport.calendar
    let rules = PointsRules.v2

    func hour(_ hour: Int, steps: Double, day: Int = 5) -> StepCount {
        let start = TestSupport.date(2026, 1, day, hour: hour)
        return StepCount(start: start, end: start + 3600, steps: steps)
    }

    @Test func stepsDuringActivityAreNotPaidTwice() {
        let bucket = hour(9, steps: 6000)
        let walk = TestSupport.sample("walk", .walk, start: bucket.start, minutes: 30)
        #expect(bucket.everydaySteps(after: .distantPast, excluding: [walk]) == 3000)
        let typed = TestSupport.sample("typed", .walk, start: bucket.start, minutes: 30, userEntered: true)
        #expect(bucket.everydaySteps(after: .distantPast, excluding: [typed]) == 6000)
    }

    @Test func stepsBeforeAMomentAreProrated() {
        let bucket = hour(9, steps: 1200)
        #expect(bucket.everydaySteps(after: bucket.start + 2700, excluding: []) == 300)
        #expect(bucket.everydaySteps(after: bucket.end, excluding: []) == 0)
    }

    @Test func stepsEarnOnePepPer200UpToTheDailyCap() {
        let earnings = rules.earnings(
            for: [], steps: [hour(9, steps: 1000), hour(10, steps: 450), hour(9, steps: 20_000, day: 6)],
            since: TestSupport.date(2026, 1, 5, hour: 0), calendar: calendar)
        #expect(earnings.map(\.sourceID) == ["steps:2026-01-05", "steps:2026-01-06"])
        #expect(earnings.map(\.amount) == [7, 25])
        #expect(earnings.allSatisfy { $0.rulesVersion == 2 })
    }

    @Test func preInstallStepsAndV1EarnNothing() {
        let steps = [hour(9, steps: 4000)]
        #expect(
            rules.earnings(for: [], steps: steps, since: TestSupport.date(2026, 1, 5, hour: 10), calendar: calendar)
                .isEmpty)
        #expect(PointsRules.v1.earnings(for: [], steps: steps, since: .distantPast, calendar: calendar).isEmpty)
    }

    @Test func walkingHatchesTheEgg() {
        let egg = StarterEgg(grantedAt: TestSupport.date(2026, 1, 5, hour: 9))
        let few = HatchRules.v1.progress(
            for: egg, samples: [], steps: [hour(9, steps: 300)], at: egg.grantedAt + 3600, calendar: calendar)
        #expect(few.activeMinutes == 3)
        #expect(few.stepsRemaining == 200)
        #expect(!few.isReady)
        let enough = HatchRules.v1.progress(
            for: egg, samples: [], steps: [hour(9, steps: 300), hour(10, steps: 250)], at: egg.grantedAt + 7200,
            calendar: calendar)
        #expect(enough.isReady)
    }

    @Test func summaryCountsTodaysSteps() {
        let summary = DailySummary(
            containing: TestSupport.date(2026, 1, 5, hour: 12), samples: [],
            steps: [hour(9, steps: 1000), hour(10, steps: 500), hour(9, steps: 99, day: 6)], earnings: [],
            calendar: calendar)
        #expect(summary.steps == 1500)
    }
}
