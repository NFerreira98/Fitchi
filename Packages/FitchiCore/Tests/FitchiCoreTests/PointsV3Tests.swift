import Foundation
import Testing

@testable import FitchiCore

@Suite("Pep earning v3: big efforts and steps-only days")
struct PointsV3Tests {
    let rules = PointsRules.v3
    let calendar = TestSupport.calendar
    let install = TestSupport.date(2026, 1, 5, hour: 0)
    let morning = TestSupport.date(2026, 1, 5, hour: 8)

    func hour(_ hour: Int, steps: Double, day: Int = 5) -> StepCount {
        let start = TestSupport.date(2026, 1, day, hour: hour)
        return StepCount(start: start, end: start + 3600, steps: steps)
    }

    @Test func currentRulesAreV3() {
        #expect(PointsRules.current == .v3)
    }

    @Test func longWorkoutsPayInFullPastTheSoftCap() {
        // A 3-hour run: 180 × 1.2 × 1.6 = 345.6 raw, way past the 180 soft cap, all paid.
        let run = TestSupport.sample("marathon", .run, start: morning, minutes: 180)
        let earnings = rules.earnings(for: [run], since: install, calendar: calendar)
        #expect(earnings.map(\.amount) == [346])
        #expect(PointsRules.v2.earnings(for: [run], since: install, calendar: calendar).map(\.amount) == [263])
    }

    @Test func workoutsUpToSixHoursCount() {
        let ultra = TestSupport.sample("ultra", .walk, start: morning, minutes: 400)
        #expect(rules.rawPep(for: ultra) == 360 * rules.basePerMinute)
    }

    @Test func passiveMinutesStillSoftCapAndWorkoutsDontUseItUp() {
        let run = TestSupport.sample("run", .run, start: morning, minutes: 120)  // 230.4
        let passive = (0..<300).map { index in
            TestSupport.sample(
                "p\(index)", .passive, start: morning.addingTimeInterval(3 * .hour + Double(index) * 60), minutes: 1)
        }
        let earnings = rules.earnings(for: [run] + passive, since: install, calendar: calendar)
        let passivePep = earnings.filter { $0.sourceID.hasPrefix("p") }.reduce(0) { $0 + $1.amount }
        // 300 passive minutes = 180 raw: exactly the cap, so all paid despite the long run.
        #expect(passivePep == 180)
        #expect(earnings.first?.amount == 230)
    }

    @Test func stepsOnlyDaysEarnOnePerHundredWithoutACap() {
        let earnings = rules.earnings(
            for: [], steps: [hour(9, steps: 12_000), hour(18, steps: 13_000)], since: install, calendar: calendar)
        #expect(earnings.map(\.amount) == [250])
        #expect(earnings.first?.rulesVersion == 3)
    }

    @Test func daysWithWatchMinutesKeepTheEverydayRate() {
        let minute = TestSupport.sample("p", .passive, start: TestSupport.date(2026, 1, 5, hour: 7), minutes: 1)
        let earnings = rules.stepEarnings(
            for: [hour(9, steps: 20_000), hour(9, steps: 20_000, day: 6)], excluding: [minute], since: install,
            calendar: calendar)
        // Day 5 had a watch on (capped at 25); day 6 was steps only.
        #expect(earnings.map(\.amount) == [25, 200])
    }

    @Test func aPhoneRecordedWorkoutStillLeavesAStepsOnlyDay() {
        // Workouts saved by iPhone apps pay as usual; steps during them aren't paid twice.
        let run = TestSupport.sample("strava", .run, start: TestSupport.date(2026, 1, 5, hour: 9), minutes: 30)
        let earnings = rules.earnings(
            for: [run], steps: [hour(9, steps: 6000), hour(12, steps: 4000)], since: install, calendar: calendar)
        #expect(earnings.map(\.amount) == [58, 70])
    }
}
