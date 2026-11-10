import FitchiCore
import Foundation
import HealthKit

/// Reads workouts and exercise minutes from Apple Health.
public struct HealthKitDataSource: HealthDataSource {
    private let store: HKHealthStore

    public init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    public var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private static var exerciseTime: HKQuantityType { HKQuantityType(.appleExerciseTime) }

    private static var readTypes: Set<HKObjectType> {
        [.workoutType(), exerciseTime, HKQuantityType(.heartRate), HKCharacteristicType(.dateOfBirth)]
    }

    public func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: Self.readTypes)
    }

    public func activity(since start: Date, until end: Date) async throws -> [ActivitySample] {
        let range = HKQuery.predicateForSamples(withStart: start, end: end)
        let workouts = try await HKSampleQueryDescriptor(
            predicates: [.workout(range)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        ).result(for: store)
        let exercise = try await HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: Self.exerciseTime, predicate: range)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        ).result(for: store)

        let mapper = ActivityMapper(effort: EffortEstimator(age: age(at: end)))
        return mapper.samples(workouts: workouts.map(WorkoutRecord.init), exercise: exercise.map(ExerciseMinuteRecord.init))
    }

    public func changes() -> AsyncStream<HealthChange> {
        let store = store
        return AsyncStream { continuation in
            let queries = [HKObjectType.workoutType(), Self.exerciseTime].map { type in
                HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                    guard error == nil else { return completion() }
                    let box = CompletionBox(completion)
                    continuation.yield(HealthChange { box.call() })
                }
            }
            queries.forEach(store.execute)
            continuation.onTermination = { _ in queries.forEach(store.stop) }
        }
    }

    public func enableBackgroundDelivery() async throws {
        try await store.enableBackgroundDelivery(for: .workoutType(), frequency: .immediate)
        try await store.enableBackgroundDelivery(for: Self.exerciseTime, frequency: .hourly)
    }

    private func age(at date: Date) -> Int? {
        guard let birthday = try? store.dateOfBirthComponents(), let born = Calendar.current.date(from: birthday) else {
            return nil
        }
        return Calendar.current.dateComponents([.year], from: born, to: date).year
    }
}

/// HealthKit's observer completion handler isn't annotated `Sendable`, but Apple documents it as
/// callable from any thread, which is all `HealthChange` needs.
private struct CompletionBox: @unchecked Sendable {
    let call: HKObserverQueryCompletionHandler

    init(_ call: @escaping HKObserverQueryCompletionHandler) {
        self.call = call
    }
}
