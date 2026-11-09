import Foundation

/// Kinds of activity that earn Pep. `passive` is exercise minutes logged outside a workout
/// (e.g. a brisk walk to class without starting a workout).
public enum ActivityKind: String, Codable, CaseIterable, Sendable, CodingKeyRepresentable {
    case walk
    case run
    case hike
    case cycling
    case swim
    case strength
    case hiit
    case yoga
    case dance
    case sports
    case other
    case passive
}

/// How hard the activity was, derived from heart-rate zones by the HealthKit adapter.
public enum Effort: String, Codable, CaseIterable, Sendable, CodingKeyRepresentable {
    case light
    case moderate
    case vigorous
    case peak
}

/// One unit of activity, platform-neutral. `FitchiHealth` maps HealthKit workouts and
/// exercise-minute samples into these.
///
/// Contract for adapters: `id` must be stable (use the HealthKit sample UUID) and passive
/// samples must not overlap workouts, so nothing is counted twice.
public struct ActivitySample: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var kind: ActivityKind
    public var start: Date
    public var end: Date
    public var effort: Effort?
    /// Typed in by hand in the Health app. These never earn Pep.
    public var isUserEntered: Bool

    public init(
        id: String,
        kind: ActivityKind,
        start: Date,
        end: Date,
        effort: Effort? = nil,
        isUserEntered: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.start = start
        self.end = end
        self.effort = effort
        self.isUserEntered = isUserEntered
    }

    public var minutes: Double { max(0, end.timeIntervalSince(start) / 60) }
}
