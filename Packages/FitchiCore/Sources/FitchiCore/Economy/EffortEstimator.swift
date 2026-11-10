import Foundation

/// Turns a workout's average heart rate into an `Effort` using zones of max heart rate.
///
/// Max heart rate uses the Tanaka formula (208 − 0.7 × age); without an age it assumes 190.
/// Zones (fraction of max): light < 64% ≤ moderate < 77% ≤ vigorous < 88% ≤ peak.
public struct EffortEstimator: Hashable, Sendable {
    public static let defaultMaxHeartRate: Double = 190

    public var maxHeartRate: Double

    public init(maxHeartRate: Double = EffortEstimator.defaultMaxHeartRate) {
        self.maxHeartRate = max(1, maxHeartRate)
    }

    public init(age: Int?) {
        self.init(maxHeartRate: age.map { 208 - 0.7 * Double($0) } ?? Self.defaultMaxHeartRate)
    }

    public func effort(averageHeartRate bpm: Double) -> Effort {
        switch bpm / maxHeartRate {
        case ..<0.64: .light
        case ..<0.77: .moderate
        case ..<0.88: .vigorous
        default: .peak
        }
    }
}
