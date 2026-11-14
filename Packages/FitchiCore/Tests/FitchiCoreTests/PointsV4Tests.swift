import Foundation
import Testing

@testable import FitchiCore

@Suite("Pep earning v4: the same steps pay the same with or without a watch")
struct PointsV4Tests {
    let rules = PointsRules.v4
    let calendar = TestSupport.calendar
    let install = TestSupport.date(2026, 1, 5, hour: 0)

    func hour(_ hour: Int, steps: Double, day: Int = 5) -> StepCount {
        let start = TestSupport.date(2026, 1, day, hour: hour)
        return StepCount(start: start, end: start + 3600, steps: steps)
    }

    func minute(_ id: String, hour: Int, day: Int = 5) -> ActivitySample {
        TestSupport.sample(id, .passive, start: TestSupport.date(2026, 1, day, hour: hour), minutes: 1)
    }

    @Test func currentRulesAreV4() {
        #expect(PointsRules.current == .v4)
    }

    @Test func aWatchDayEarnsLikeAStepsOnlyDay() {
        // Day 5 had a watch on (one exercise minute at 7:00), day 6 didn't: 20,000 steps each.
        let earnings = rules.stepEarnings(
            for: [hour(9, steps: 20_000), hour(9, steps: 20_000, day: 6)], excluding: [minute("p", hour: 7)],
            since: install, calendar: calendar)
        #expect(earnings.map(\.amount) == [200, 200])
        #expect(earnings.allSatisfy { $0.rulesVersion == 4 })
        // v3 paid the watch day 25.
        let v3 = PointsRules.v3.stepEarnings(
            for: [hour(9, steps: 20_000)], excluding: [minute("p", hour: 7)], since: install, calendar: calendar)
        #expect(v3.map(\.amount) == [25])
    }

    @Test func stepsDuringExerciseMinutesStillDontPayTwice() {
        // A brisk hour at 9:00 the watch logged as exercise: its steps are left out.
        let brisk = (0..<60).map { minute in
            TestSupport.sample(
                "b\(minute)", .passive,
                start: TestSupport.date(2026, 1, 5, hour: 9).addingTimeInterval(Double(minute) * 60), minutes: 1)
        }
        let earnings = rules.stepEarnings(
            for: [hour(9, steps: 6000), hour(14, steps: 3000)], excluding: brisk, since: install, calendar: calendar)
        #expect(earnings.map(\.amount) == [30])
    }

    @Test func theCasualWatchWalkerEarnsAboutWhatTheyWouldWithoutIt() {
        // 6,000 steps over the day, 15 of those minutes brisk enough to count as exercise.
        let steps = (8..<20).map { hour($0, steps: 500) }
        let brisk = (0..<15).map { index in
            TestSupport.sample(
                "b\(index)", .passive,
                start: TestSupport.date(2026, 1, 5, hour: 12).addingTimeInterval(Double(index) * 60), minutes: 1)
        }
        let total = { (rules: PointsRules, samples: [ActivitySample]) in
            rules.earnings(for: samples, steps: steps, since: install, calendar: calendar).reduce(0) { $0 + $1.amount }
        }
        let phoneOnly = total(rules, [])
        let withWatch = total(rules, brisk)
        #expect(phoneOnly == 60)
        #expect(withWatch >= phoneOnly - 5)
        #expect(total(.v3, brisk) < withWatch)
    }
}
