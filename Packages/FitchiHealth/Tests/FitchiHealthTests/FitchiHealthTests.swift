import FitchiCore
import Foundation
import HealthKit
import Testing
@testable import FitchiHealth

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
    return calendar
}()

private let morning = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 8)) ?? .distantPast

private func at(_ minutes: Double) -> Date { morning.addingTimeInterval(minutes * 60) }

@Suite("Health mapping")
struct ActivityMapperTests {
    @Test(arguments: [
        (HKWorkoutActivityType.walking, ActivityKind.walk),
        (.running, .run),
        (.traditionalStrengthTraining, .strength),
        (.highIntensityIntervalTraining, .hiit),
        (.swimming, .swim),
        (.soccer, .sports),
        (.fishing, .other),
    ])
    func workoutTypes(type: HKWorkoutActivityType, expected: ActivityKind) {
        #expect(ActivityMapper.kind(for: type) == expected)
    }

    @Test func mapsWorkoutsWithEffortAndPausedTimeExcluded() throws {
        let mapper = ActivityMapper(effort: EffortEstimator(maxHeartRate: 190))
        let samples = mapper.samples(
            workouts: [WorkoutRecord(id: "run", activityType: .running, start: morning, duration: 25 * 60, averageHeartRate: 160)],
            exercise: []
        )
        let run = try #require(samples.first)
        #expect(run.kind == .run)
        #expect(run.effort == .vigorous)
        #expect(run.minutes == 25)
    }

    @Test func exerciseMinutesDuringAWorkoutAreNotCountedTwice() {
        let samples = ActivityMapper().samples(
            workouts: [WorkoutRecord(id: "walk", activityType: .walking, start: morning, duration: 30 * 60)],
            exercise: [
                ExerciseMinuteRecord(id: "during", start: at(10), end: at(11), minutes: 1),
                ExerciseMinuteRecord(id: "later", start: at(45), end: at(46), minutes: 1),
            ]
        )
        #expect(samples.map(\.id) == ["walk", "later"])
        #expect(samples.last?.kind == .passive)
    }

    @Test func keepsHandEnteredFlag() {
        let samples = ActivityMapper().samples(
            workouts: [WorkoutRecord(id: "typed", activityType: .running, start: morning, duration: 1800, isUserEntered: true)],
            exercise: []
        )
        #expect(samples.first?.isUserEntered == true)
    }
}

@Suite("Activity store")
@MainActor
struct ActivityStoreTests {
    let install = morning.addingTimeInterval(-3600)

    func store(_ source: FakeHealthDataSource, now: Date = at(600)) -> ActivityStore {
        ActivityStore(source: source, installDate: install, clock: FixedClock(now), calendar: calendar)
    }

    @Test func loadsTodayAndBalanceIncludingWelcomeBonus() async {
        let source = FakeHealthDataSource(samples: [
            ActivitySample(id: "walk", kind: .walk, start: morning, end: at(20)),
            ActivitySample(id: "early", kind: .run, start: install - 7200, end: install - 3600),
        ])
        let store = store(source)
        await store.start()
        #expect(store.status == .ready)
        #expect(store.today.activeMinutes == 20)
        #expect(store.today.pepEarned == 24)
        #expect(store.wallet.balance == 124)
    }

    @Test func reportsUnavailableAndPermissionFailures() async {
        let unavailable = store(FakeHealthDataSource(isAvailable: false))
        await unavailable.start()
        #expect(unavailable.status == .unavailable)

        let denied = store(FakeHealthDataSource(failsAuthorization: true))
        await denied.start()
        #expect(denied.status == .failed("Couldn't get Health permission."))
    }

    @Test func fakeSampleDayOnlyIncludesThePast() {
        let noon = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 12)) ?? .distantPast
        let day = FakeHealthDataSource.sampleDay(endingAt: noon, calendar: calendar)
        #expect(day.samples.map(\.id) == ["fake-walk"])
    }
}
