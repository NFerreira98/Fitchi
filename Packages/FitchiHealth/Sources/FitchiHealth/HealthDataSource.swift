import FitchiCore
import Foundation

/// Where activity comes from. `HealthKitDataSource` in the apps, `FakeHealthDataSource` in
/// tests, previews and the simulator.
public protocol HealthDataSource: Sendable {
    /// False when the device has no Health database (e.g. macOS, some iPads).
    var isAvailable: Bool { get }

    /// Shows the Health permission sheet the first time; a no-op afterwards. Apple never reveals
    /// whether *read* access was granted: a denied user simply returns no samples.
    func requestAuthorization() async throws

    /// Every earning-relevant sample overlapping `start..<end`, already mapped and with
    /// overlaps resolved (see `ActivitySample.resolvingOverlaps`).
    func activity(since start: Date, until end: Date) async throws -> [ActivitySample]

    /// Hourly step totals overlapping `start..<end`, merged across devices, without
    /// hand-entered steps.
    func steps(since start: Date, until end: Date) async throws -> [StepCount]

    /// Fires whenever Health gets new activity. Call `acknowledge()` once you've handled it, so
    /// watchOS knows a background wake-up finished.
    func changes() -> AsyncStream<HealthChange>

    /// Asks the system to wake the app when new workouts arrive, even in the background.
    func enableBackgroundDelivery() async throws
}

/// One "Health has new data" signal.
public struct HealthChange: Sendable {
    private let onAcknowledge: @Sendable () -> Void

    public init(onAcknowledge: @escaping @Sendable () -> Void = {}) {
        self.onAcknowledge = onAcknowledge
    }

    public func acknowledge() { onAcknowledge() }
}

public enum HealthDataError: Error, Sendable {
    case authorizationFailed
}

/// A canned data source. Returns its samples (filtered to the requested range) and never
/// reports changes.
public struct FakeHealthDataSource: HealthDataSource {
    public var samples: [ActivitySample]
    public var stepCounts: [StepCount]
    public var isAvailable: Bool
    public var failsAuthorization: Bool

    public init(
        samples: [ActivitySample] = [], steps: [StepCount] = [], isAvailable: Bool = true,
        failsAuthorization: Bool = false
    ) {
        self.samples = samples
        self.stepCounts = steps
        self.isAvailable = isAvailable
        self.failsAuthorization = failsAuthorization
    }

    public func requestAuthorization() async throws {
        if failsAuthorization { throw HealthDataError.authorizationFailed }
    }

    public func activity(since start: Date, until end: Date) async throws -> [ActivitySample] {
        ActivitySample.resolvingOverlaps(samples.filter { $0.end > start && $0.start < end })
    }

    public func steps(since start: Date, until end: Date) async throws -> [StepCount] {
        stepCounts.filter { $0.end > start && $0.start < end }
    }

    public func changes() -> AsyncStream<HealthChange> {
        AsyncStream { $0.finish() }
    }

    public func enableBackgroundDelivery() async throws {}

    /// A believable day so far: a morning walk, a lunchtime run, some passive minutes and steps.
    public static func sampleDay(endingAt now: Date = Date(), calendar: Calendar = .current) -> FakeHealthDataSource {
        let day = calendar.startOfDay(for: now)
        func at(_ hour: Double) -> Date { day.addingTimeInterval(hour * 3600) }
        var samples = [
            ActivitySample(id: "fake-walk", kind: .walk, start: at(7.5), end: at(8), effort: .moderate),
            ActivitySample(id: "fake-run", kind: .run, start: at(12.25), end: at(12.75), effort: .vigorous),
        ]
        for minute in 0..<12 {
            let start = at(16) + Double(minute) * 60
            samples.append(ActivitySample(id: "fake-passive-\(minute)", kind: .passive, start: start, end: start + 60))
        }
        var steps: [StepCount] = []
        for hour in 7..<20 {
            let walked: Double = hour == 7 || hour == 12 ? 3200 : 450
            steps.append(StepCount(start: at(Double(hour)), end: at(Double(hour + 1)), steps: walked))
        }
        return FakeHealthDataSource(samples: samples.filter { $0.end <= now }, steps: steps.filter { $0.end <= now })
    }
}
