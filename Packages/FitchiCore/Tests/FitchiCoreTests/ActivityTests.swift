import Foundation
import Testing
@testable import FitchiCore

@Suite("Overlaps, effort and daily summary")
struct ActivityTests {
    let morning = TestSupport.date(hour: 8)

    func at(_ minutes: Double) -> Date { morning.addingTimeInterval(minutes * 60) }

    @Test func passiveMinutesInsideAWorkoutAreDropped() {
        let resolved = ActivitySample.resolvingOverlaps([
            TestSupport.sample("run", .run, start: morning, minutes: 30),
            TestSupport.sample("p-inside", .passive, start: at(10), minutes: 1),
            TestSupport.sample("p-after", .passive, start: at(31), minutes: 1),
        ])
        #expect(resolved.map(\.id) == ["run", "p-after"])
    }

    @Test func sameRunRecordedTwiceCountsOnce() {
        let resolved = ActivitySample.resolvingOverlaps([
            TestSupport.sample("strava", .run, start: at(1), minutes: 30),
            TestSupport.sample("apple", .run, start: morning, minutes: 30),
        ])
        #expect(resolved.map(\.id) == ["apple", "strava"])
        #expect(resolved[1].start == at(30))
        #expect(resolved.reduce(0) { $0 + $1.minutes } == 31)
    }

    @Test func fullyCoveredWorkoutIsDropped() {
        let resolved = ActivitySample.resolvingOverlaps([
            TestSupport.sample("long", .walk, start: morning, minutes: 60),
            TestSupport.sample("inner", .run, start: at(10), minutes: 20),
        ])
        #expect(resolved.map(\.id) == ["long"])
    }

    @Test func handEnteredSamplesNeverBlockRealOnes() {
        let resolved = ActivitySample.resolvingOverlaps([
            TestSupport.sample("typed", .run, start: morning, minutes: 60, userEntered: true),
            TestSupport.sample("real", .passive, start: at(5), minutes: 1),
        ])
        #expect(Set(resolved.map(\.id)) == ["typed", "real"])
    }

    @Test(arguments: [(90.0, Effort.light), (130, .moderate), (155, .vigorous), (175, .peak)])
    func heartRateZones(bpm: Double, expected: Effort) {
        #expect(EffortEstimator(maxHeartRate: 190).effort(averageHeartRate: bpm) == expected)
    }

    @Test func maxHeartRateFromAge() {
        #expect(EffortEstimator(age: 30).maxHeartRate == 187)
        #expect(EffortEstimator(age: nil).maxHeartRate == 190)
    }

    @Test func dailySummaryCountsOnlyTodaysEarnedActivity() {
        let install = TestSupport.date(hour: 6) - .day * 2
        let samples = [
            TestSupport.sample("walk", .walk, start: morning, minutes: 20),
            TestSupport.sample("p", .passive, start: at(60), minutes: 5),
            TestSupport.sample("typed", .run, start: at(120), minutes: 30, userEntered: true),
            TestSupport.sample("yesterday", .run, start: morning.addingTimeInterval(-.day), minutes: 30),
        ]
        let earnings = PointsRules.v1.earnings(for: samples, since: install, calendar: TestSupport.calendar)
        let summary = DailySummary(containing: at(300), samples: samples, earnings: earnings, calendar: TestSupport.calendar)
        #expect(summary.activeMinutes == 25)
        #expect(summary.workoutCount == 1)
        #expect(summary.pepEarned == 24 + 3)  // 20×1.2, 5×1.2×0.5
    }
}
