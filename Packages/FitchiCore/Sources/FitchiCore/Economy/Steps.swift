import Foundation

/// Steps taken in one time bucket (an hour), already merged across devices by the Health
/// adapter so the watch and phone never count the same step twice. Hand-entered steps are
/// excluded before they get here.
public struct StepCount: Codable, Hashable, Sendable {
    public var start: Date
    public var end: Date
    public var steps: Double

    public init(start: Date, end: Date, steps: Double) {
        self.start = start
        self.end = end
        self.steps = steps
    }

    public var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }

    /// Steps in this bucket after `date` and outside `activity`, spread evenly across the hour.
    /// Workouts and exercise minutes already pay for the steps taken during them.
    public func everydaySteps(after date: Date, excluding activity: [ActivitySample]) -> Double {
        guard duration > 0, steps > 0 else { return 0 }
        let from = max(start, date)
        guard from < end else { return 0 }
        var uncovered = end.timeIntervalSince(from)
        // Adapters resolve overlaps between samples, so their overlaps with the bucket just add up.
        for sample in activity where !sample.isUserEntered {
            let overlap = min(sample.end, end).timeIntervalSince(max(sample.start, from))
            if overlap > 0 { uncovered -= overlap }
        }
        return steps * max(0, uncovered) / duration
    }
}

public extension Array where Element == StepCount {
    /// Everyday steps (outside workouts and exercise minutes) after `date`.
    func everydaySteps(after date: Date, excluding activity: [ActivitySample]) -> Double {
        reduce(0) { $0 + $1.everydaySteps(after: date, excluding: activity) }
    }
}
