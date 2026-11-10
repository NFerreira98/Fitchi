import Foundation

extension ActivitySample {
    /// Makes sure no stretch of time is counted twice, which `PointsRules` relies on.
    ///
    /// - Workouts win over passive exercise minutes. A passive sample that touches any workout
    ///   is dropped.
    /// - Overlapping samples of the same tier (e.g. one run recorded by two apps) keep the
    ///   earliest-starting one; the later one is trimmed to start where the earlier ends, or
    ///   dropped if fully covered.
    /// - Hand-entered samples pass through unchanged and never block real ones (they earn
    ///   nothing anyway).
    ///
    /// Trimmed samples keep their id, so earnings stay keyed to the original HealthKit sample.
    public static func resolvingOverlaps(_ samples: [ActivitySample]) -> [ActivitySample] {
        let real = samples.filter { !$0.isUserEntered }
        let workouts = trimmingOverlaps(real.filter { $0.kind != .passive })
        let passive = trimmingOverlaps(
            real.filter { candidate in
                candidate.kind == .passive
                    && !workouts.contains { $0.start < candidate.end && candidate.start < $0.end }
            }
        )
        let handEntered = samples.filter(\.isUserEntered)
        return (workouts + passive + handEntered).sorted { ($0.start, $0.id) < ($1.start, $1.id) }
    }

    /// Within one tier: walk in start order and trim each sample past everything kept so far.
    private static func trimmingOverlaps(_ samples: [ActivitySample]) -> [ActivitySample] {
        var kept: [ActivitySample] = []
        var coveredUntil = Date.distantPast
        for var sample in samples.sorted(by: { ($0.start, $0.id) < ($1.start, $1.id) }) {
            if sample.start < coveredUntil { sample.start = coveredUntil }
            guard sample.end > sample.start else { continue }
            kept.append(sample)
            coveredUntil = max(coveredUntil, sample.end)
        }
        return kept
    }
}
