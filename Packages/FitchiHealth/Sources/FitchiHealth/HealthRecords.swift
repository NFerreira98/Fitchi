import FitchiCore
import Foundation
import HealthKit

/// The parts of an `HKWorkout` that matter for Pep, copied out so mapping is testable without
/// a Health database.
public struct WorkoutRecord: Hashable, Sendable {
    public var id: String
    public var activityType: HKWorkoutActivityType
    public var start: Date
    /// Active time, excluding pauses.
    public var duration: TimeInterval
    public var averageHeartRate: Double?
    public var isUserEntered: Bool

    public init(
        id: String,
        activityType: HKWorkoutActivityType,
        start: Date,
        duration: TimeInterval,
        averageHeartRate: Double? = nil,
        isUserEntered: Bool = false
    ) {
        self.id = id
        self.activityType = activityType
        self.start = start
        self.duration = duration
        self.averageHeartRate = averageHeartRate
        self.isUserEntered = isUserEntered
    }
}

/// One Apple "exercise minutes" sample (usually a single minute of brisk movement).
public struct ExerciseMinuteRecord: Hashable, Sendable {
    public var id: String
    public var start: Date
    public var end: Date
    public var minutes: Double
    public var isUserEntered: Bool

    public init(id: String, start: Date, end: Date, minutes: Double, isUserEntered: Bool = false) {
        self.id = id
        self.start = start
        self.end = end
        self.minutes = minutes
        self.isUserEntered = isUserEntered
    }
}

extension WorkoutRecord {
    init(_ workout: HKWorkout) {
        let bpm = HKUnit.count().unitDivided(by: .minute())
        self.init(
            id: workout.uuid.uuidString,
            activityType: workout.workoutActivityType,
            start: workout.startDate,
            duration: workout.duration,
            averageHeartRate: workout.statistics(for: HKQuantityType(.heartRate))?
                .averageQuantity()?.doubleValue(for: bpm),
            isUserEntered: workout.isUserEntered
        )
    }
}

extension ExerciseMinuteRecord {
    init(_ sample: HKQuantitySample) {
        self.init(
            id: sample.uuid.uuidString,
            start: sample.startDate,
            end: sample.endDate,
            minutes: sample.quantity.doubleValue(for: .minute()),
            isUserEntered: sample.isUserEntered
        )
    }
}

extension HKObject {
    var isUserEntered: Bool { (metadata?[HKMetadataKeyWasUserEntered] as? Bool) ?? false }
}
