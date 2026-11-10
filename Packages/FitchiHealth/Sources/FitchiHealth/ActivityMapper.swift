import FitchiCore
import Foundation
import HealthKit

/// Maps Health records into FitchiCore `ActivitySample`s.
public struct ActivityMapper: Hashable, Sendable {
    public var effort: EffortEstimator

    public init(effort: EffortEstimator = EffortEstimator()) {
        self.effort = effort
    }

    public func samples(workouts: [WorkoutRecord], exercise: [ExerciseMinuteRecord]) -> [ActivitySample] {
        let workoutSamples = workouts.map { record in
            ActivitySample(
                id: record.id,
                kind: Self.kind(for: record.activityType),
                start: record.start,
                end: record.start.addingTimeInterval(max(0, record.duration)),
                effort: record.averageHeartRate.map { effort.effort(averageHeartRate: $0) },
                isUserEntered: record.isUserEntered
            )
        }
        let passiveSamples = exercise.map { record in
            ActivitySample(
                id: record.id,
                kind: .passive,
                start: record.start,
                end: min(record.end, record.start.addingTimeInterval(max(0, record.minutes) * 60)),
                isUserEntered: record.isUserEntered
            )
        }
        return ActivitySample.resolvingOverlaps(workoutSamples + passiveSamples)
    }

    /// Which Pep multiplier a Health workout type gets. Unlisted types earn at the `.other` rate.
    public static func kind(for type: HKWorkoutActivityType) -> ActivityKind {
        kinds[type] ?? .other
    }

    private static let kinds: [HKWorkoutActivityType: ActivityKind] = {
        let groups: [ActivityKind: [HKWorkoutActivityType]] = [
            .walk: [.walking, .wheelchairWalkPace],
            .run: [.running, .wheelchairRunPace],
            .hike: [.hiking, .climbing],
            .cycling: [.cycling, .handCycling, .rowing, .elliptical, .stairClimbing, .stairs, .crossCountrySkiing],
            .swim: [.swimming, .waterFitness, .surfingSports, .paddleSports],
            .strength: [.traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining],
            .hiit: [.highIntensityIntervalTraining, .crossTraining, .mixedCardio, .jumpRope, .kickboxing, .boxing],
            .yoga: [.yoga, .pilates, .mindAndBody, .flexibility, .taiChi, .barre, .cooldown],
            .dance: [.cardioDance, .socialDance],
            .sports: [
                .soccer, .basketball, .tennis, .volleyball, .americanFootball, .rugby, .hockey, .badminton,
                .tableTennis, .pickleball, .baseball, .softball, .lacrosse, .handball, .squash, .racquetball,
                .martialArts, .australianFootball,
            ],
        ]
        return groups.reduce(into: [:]) { table, group in
            for type in group.value { table[type] = group.key }
        }
    }()
}
