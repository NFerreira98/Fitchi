import FitchiCore
import HealthKit

/// HealthKit adapter namespace. Authorization, anchored queries and background delivery
/// arrive in Milestone 3.
public enum FitchiHealth {
    /// Whether HealthKit is usable on this device (false on e.g. some iPads and macOS).
    public static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }
}
