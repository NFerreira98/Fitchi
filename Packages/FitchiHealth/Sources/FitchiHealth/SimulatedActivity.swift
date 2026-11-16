import FitchiCore
import Foundation

/// Developer tools: pretend walks and steps, added on top of what Health has so a comeback,
/// quests, cheers or an egg can be tried without going out. Saved on this device only (never
/// written to Health, so the other device doesn't see it).
///
/// Each new walk or batch of steps starts now, or where the last one ends if that is still
/// going, so they never overlap: steps during a walk wouldn't count, just as with real ones.
public struct SimulatedActivity: Codable, Equatable, Sendable {
    public var samples: [ActivitySample] = []
    public var steps: [StepCount] = []

    /// `UserDefaults` key.
    public static let key = "fitchi.dev.simulatedActivity"
    /// Batches of steps take a minute per 100 steps (like the comeback quest counts them).
    public static let stepsPerMinute = 100.0

    public init() {}

    public var isEmpty: Bool { samples.isEmpty && steps.isEmpty }
    public var walkMinutes: Double { samples.reduce(0) { $0 + $1.minutes } }
    public var stepTotal: Double { steps.reduce(0) { $0 + $1.steps } }

    public mutating func addWalk(minutes: Double, at now: Date) {
        let start = nextStart(at: now)
        samples.append(
            ActivitySample(
                id: "simulated-walk-\(UUID().uuidString)", kind: .walk, start: start,
                end: start.addingTimeInterval(minutes * 60), effort: .moderate))
    }

    public mutating func addSteps(_ count: Double, at now: Date) {
        let start = nextStart(at: now)
        steps.append(
            StepCount(start: start, end: start.addingTimeInterval(count / Self.stepsPerMinute * 60), steps: count))
    }

    func nextStart(at now: Date) -> Date {
        max(now, (samples.map(\.end) + steps.map(\.end)).max() ?? now)
    }

    static func load(from defaults: UserDefaults?) -> SimulatedActivity {
        guard let data = defaults?.data(forKey: key) else { return SimulatedActivity() }
        return (try? JSONDecoder().decode(SimulatedActivity.self, from: data)) ?? SimulatedActivity()
    }

    func save(to defaults: UserDefaults?) {
        if isEmpty {
            defaults?.removeObject(forKey: Self.key)
        } else {
            defaults?.set(try? JSONEncoder().encode(self), forKey: Self.key)
        }
    }
}

extension ActivityStore {
    /// Developer tools: a pretend walk of `minutes`, counted like a real one.
    public func simulateWalk(minutes: Double) async {
        simulated.addWalk(minutes: minutes, at: clock.now)
        await saveSimulated()
    }

    /// Developer tools: pretend everyday steps.
    public func simulateSteps(_ count: Double) async {
        simulated.addSteps(count, at: clock.now)
        await saveSimulated()
    }

    /// Developer tools: takes back every pretend walk and step (and the Pep they earned).
    public func clearSimulated() async {
        simulated = SimulatedActivity()
        await saveSimulated()
    }

    private func saveSimulated() async {
        simulated.save(to: simulatedDefaults)
        await refresh()
    }
}
