import Foundation
import Testing
@testable import FitchiCore

@Suite("Pep earning")
struct PointsTests {
    let rules = PointsRules.v1
    let install = TestSupport.date(hour: 6)
    let morning = TestSupport.date(hour: 8)

    func earn(_ samples: [ActivitySample]) -> [Earning] {
        rules.earnings(for: samples, since: install, calendar: TestSupport.calendar)
    }

    @Test func runEarnsMoreThanWalkForSameTime() {
        let earnings = earn([
            TestSupport.sample("walk", .walk, start: morning, minutes: 30, effort: .moderate),
            TestSupport.sample("run", .run, start: morning.addingTimeInterval(.hour), minutes: 30, effort: .moderate),
        ])
        #expect(earnings.map(\.amount) == [40, 63])  // 30×1.2×1.0×1.1, 30×1.2×1.6×1.1
    }

    @Test func effortIncreasesPep() {
        let light = rules.rawPep(for: TestSupport.sample("a", .run, start: morning, minutes: 30, effort: .light))
        let peak = rules.rawPep(for: TestSupport.sample("b", .run, start: morning, minutes: 30, effort: .peak))
        #expect(peak > light)
    }

    @Test func excludesHandEnteredPreInstallAndDuplicates() {
        let earnings = earn([
            TestSupport.sample("typed", .run, start: morning, minutes: 30, userEntered: true),
            TestSupport.sample("early", .run, start: install.addingTimeInterval(-60), minutes: 30),
            TestSupport.sample("real", .walk, start: morning, minutes: 10),
            TestSupport.sample("real", .walk, start: morning, minutes: 10),
        ])
        #expect(earnings.map(\.sourceID) == ["real"])
    }

    @Test func softCapHalvesPepBeyondDailyLimit() {
        // 150 min walk = 180 raw (exactly the cap); a further 50 min walk = 60 raw → 30 after cap.
        let earnings = earn([
            TestSupport.sample("long", .walk, start: morning, minutes: 150),
            TestSupport.sample("more", .walk, start: morning.addingTimeInterval(3 * .hour), minutes: 50),
            TestSupport.sample("tomorrow", .walk, start: morning.addingTimeInterval(.day), minutes: 50),
        ])
        #expect(earnings.map(\.amount) == [180, 30, 60])
    }

    @Test func absurdlyLongSamplesAreClamped() {
        let overnight = TestSupport.sample("oops", .walk, start: morning, minutes: 900)
        #expect(rules.rawPep(for: overnight) == rules.maxMinutesPerSample * rules.basePerMinute)
    }

    @Test func passiveMinutesEarnAtReducedRate() {
        let passive = rules.rawPep(for: TestSupport.sample("p", .passive, start: morning, minutes: 20))
        let walk = rules.rawPep(for: TestSupport.sample("w", .walk, start: morning, minutes: 20))
        #expect(passive == walk / 2)
    }

    @Test func thirtyMinutesOfWalkingCoversADayOfBasicCare() {
        // Design target: ~30 min of moderate exercise keeps one pet comfortably cared for.
        let pep = rules.rawPep(for: TestSupport.sample("w", .walk, start: morning, minutes: 30, effort: .moderate))
        let catalog = TestSupport.catalog
        let dailyBasics = ["kibble", "tennis-ball", "nap-mat", "grooming-brush"]
            .compactMap { catalog.item(id: $0)?.price }
            .reduce(0, +)
        #expect(pep > Double(dailyBasics))
    }
}
