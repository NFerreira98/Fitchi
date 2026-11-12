import FitchiCore
import Foundation
import Observation

/// Live view of the player's activity and Pep, shared by the watch and phone UIs.
///
/// Re-reads Health on every change and recomputes earnings from scratch. That's cheap and
/// idempotent because earnings are keyed by sample id. (Milestone 4 persists earnings and
/// switches to anchored queries.)
@Observable
@MainActor
public final class ActivityStore {
    public enum Status: Equatable, Sendable {
        case idle
        case loading
        case ready
        /// No Health database on this device.
        case unavailable
        case failed(String)
    }

    public private(set) var status: Status = .idle
    public private(set) var samples: [ActivitySample] = []
    public private(set) var steps: [StepCount] = []
    public private(set) var earnings: [Earning] = []
    public private(set) var lastRefreshed: Date?

    public private(set) var installDate: Date
    public let rules: PointsRules
    private let source: any HealthDataSource
    private let clock: any GameClock
    private let calendar: Calendar
    private var isObserving = false

    public init(
        source: any HealthDataSource,
        installDate: Date,
        rules: PointsRules = .current,
        clock: any GameClock = SystemClock(),
        calendar: Calendar = .current
    ) {
        self.source = source
        self.installDate = installDate
        self.rules = rules
        self.clock = clock
        self.calendar = calendar
    }

    /// Balance so far: activity earnings plus the welcome bonus. (Spending arrives with the shop.)
    public var wallet: Wallet {
        Wallet(earnings: earnings, transactions: [.welcomeBonus(rules.welcomeBonus, at: installDate)])
    }

    public var today: DailySummary {
        DailySummary(containing: clock.now, samples: samples, steps: steps, earnings: earnings, calendar: calendar)
    }

    /// Asks for permission, loads activity, then keeps it current until the calling task is
    /// cancelled. Safe to call more than once; only the first call observes.
    public func start(backgroundDelivery: Bool = false) async {
        guard source.isAvailable else {
            status = .unavailable
            return
        }
        do {
            try await source.requestAuthorization()
        } catch {
            status = .failed("Couldn't get Health permission.")
            return
        }
        if backgroundDelivery { try? await source.enableBackgroundDelivery() }
        await refresh()

        guard !isObserving else { return }
        isObserving = true
        defer { isObserving = false }
        for await change in source.changes() {
            await refresh()
            change.acknowledge()
        }
    }

    /// Counts activity from an earlier install date (restored from a backup).
    public func adoptInstallDate(_ date: Date) {
        guard date < installDate else { return }
        installDate = date
        Task { await refresh() }
    }

    public func refresh() async {
        guard source.isAvailable else {
            status = .unavailable
            return
        }
        if lastRefreshed == nil { status = .loading }
        let now = clock.now
        do {
            let fetched = try await source.activity(since: installDate, until: now)
            // Steps are a bonus: if they can't be read, workouts and exercise minutes still count.
            let fetchedSteps = (try? await source.steps(since: installDate, until: now)) ?? []
            samples = fetched
            steps = fetchedSteps
            earnings = rules.earnings(for: fetched, steps: fetchedSteps, since: installDate, calendar: calendar)
            lastRefreshed = now
            status = .ready
        } catch {
            status = .failed("Couldn't read Health data.")
        }
    }
}

extension ActivityStore {
    /// The real Health store on devices; a canned day in the simulator (which has no workouts).
    public static func makeDefault(installDate: Date) -> ActivityStore {
        #if targetEnvironment(simulator)
            let start = Calendar.current.startOfDay(for: Date())
            return ActivityStore(source: FakeHealthDataSource.sampleDay(), installDate: min(installDate, start))
        #else
            return ActivityStore(source: HealthKitDataSource(), installDate: installDate)
        #endif
    }

    /// For SwiftUI previews.
    public static func preview(now: Date = Date()) -> ActivityStore {
        ActivityStore(
            source: FakeHealthDataSource.sampleDay(endingAt: now),
            installDate: Calendar.current.startOfDay(for: now)
        )
    }
}
