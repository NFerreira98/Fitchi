import Foundation

/// How long a pet stays visibly pumped after you work out.
public struct AfterglowRules: Hashable, Sendable {
    public var version: Int
    /// The shortest workout that counts, in minutes.
    public var minimumMinutes: Double
    /// How long the glow lasts after the workout ends, in minutes, fading all the way.
    public var lastsMinutes: Double

    public static let v1 = AfterglowRules(version: 1, minimumMinutes: 10, lastsMinutes: 60)
}

/// The pet's buzz after a workout: 1 right as one ends, fading to 0 an hour later. Computed from
/// Health samples like everything else, so the watch and the phone agree.
public enum Afterglow {
    /// 0…1. Only real workouts count: not passive exercise minutes, nothing typed in by hand.
    public static func level(at date: Date, samples: [ActivitySample], rules: AfterglowRules = .v1) -> Double {
        let lasts = rules.lastsMinutes * 60
        let latest =
            samples
            .filter { sample in
                sample.kind != .passive && !sample.isUserEntered
                    && sample.end.timeIntervalSince(sample.start) >= rules.minimumMinutes * 60
                    && sample.end <= date
            }
            .map(\.end)
            .max()
        guard let latest else { return 0 }
        let since = date.timeIntervalSince(latest)
        return since < lasts ? 1 - since / lasts : 0
    }
}
