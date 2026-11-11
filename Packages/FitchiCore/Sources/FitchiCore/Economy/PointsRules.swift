import Foundation

/// Pep earned from one activity sample. Keyed by the sample's id, so recomputing is idempotent
/// across devices (watch and phone can both read HealthKit without double-counting).
public struct Earning: Codable, Hashable, Sendable, Identifiable {
    public var sourceID: String
    public var day: Date
    public var amount: Int
    public var rulesVersion: Int

    public init(sourceID: String, day: Date, amount: Int, rulesVersion: Int) {
        self.sourceID = sourceID
        self.day = day
        self.amount = amount
        self.rulesVersion = rulesVersion
    }

    public var id: String { sourceID }
}

/// How activity turns into Pep.
///
/// pep = minutes × basePerMinute × activity multiplier × effort bonus,
/// at full rate up to `dailySoftCap` per day and `overCapRate` beyond it.
///
/// From v2, everyday steps (outside workouts and exercise minutes) also earn a little:
/// one Pep per `stepsPerPep`, up to `stepPepDailyCap` a day, separate from the soft cap.
public struct PointsRules: Hashable, Sendable {
    public var version: Int
    public var basePerMinute: Double
    public var multipliers: [ActivityKind: Double]
    public var effortBonus: [Effort: Double]
    public var dailySoftCap: Double
    public var overCapRate: Double
    /// Guards against bogus samples (e.g. a workout left running overnight).
    public var maxMinutesPerSample: Double
    /// One-time Pep granted at install, so the first treat is affordable straight away.
    public var welcomeBonus: Int
    /// Everyday steps per Pep; nil means steps earn nothing.
    public var stepsPerPep: Double?
    public var stepPepDailyCap: Double

    /// The rules the apps use now.
    public static let current = v2

    public static let v1 = PointsRules(
        version: 1,
        basePerMinute: 1.2,
        multipliers: [
            .walk: 1.0, .yoga: 1.0, .dance: 1.2, .hike: 1.3, .cycling: 1.3, .strength: 1.4,
            .sports: 1.4, .run: 1.6, .swim: 1.7, .hiit: 1.8, .other: 1.0, .passive: 0.5,
        ],
        effortBonus: [.light: 1.0, .moderate: 1.1, .vigorous: 1.25, .peak: 1.4],
        dailySoftCap: 180,
        overCapRate: 0.5,
        maxMinutesPerSample: 240,
        welcomeBonus: 100,
        stepsPerPep: nil,
        stepPepDailyCap: 0
    )

    /// v1 plus a trickle of Pep for everyday walking: about 0.5 Pep per minute of walking,
    /// up to 25 a day (5,000 steps), so moving around helps without replacing exercise.
    public static let v2: PointsRules = {
        var rules = v1
        rules.version = 2
        rules.stepsPerPep = 200
        rules.stepPepDailyCap = 25
        return rules
    }()

    /// Raw Pep for a sample, before the daily cap.
    public func rawPep(for sample: ActivitySample) -> Double {
        let minutes = min(sample.minutes, maxMinutesPerSample)
        let multiplier = multipliers[sample.kind] ?? 1
        let bonus = sample.effort.flatMap { effortBonus[$0] } ?? 1
        return minutes * basePerMinute * multiplier * bonus
    }

    /// Computes earnings for every eligible sample. Excludes hand-entered samples, samples from
    /// before `installDate`, and duplicate ids. Each day's soft cap is applied in start order.
    /// Everyday steps add one earning per day (see `stepEarnings`).
    public func earnings(
        for samples: [ActivitySample],
        steps: [StepCount] = [],
        since installDate: Date,
        calendar: Calendar
    ) -> [Earning] {
        activityEarnings(for: samples, since: installDate, calendar: calendar)
            + stepEarnings(for: steps, excluding: samples, since: installDate, calendar: calendar)
    }

    /// One earning per day for everyday steps, keyed by the day so recomputing replaces it.
    public func stepEarnings(
        for steps: [StepCount],
        excluding samples: [ActivitySample],
        since installDate: Date,
        calendar: Calendar
    ) -> [Earning] {
        guard let stepsPerPep, stepsPerPep > 0 else { return [] }
        var totals: [Date: Double] = [:]
        for bucket in steps {
            let day = calendar.startOfDay(for: bucket.start)
            totals[day, default: 0] += bucket.everydaySteps(after: installDate, excluding: samples)
        }
        return totals.keys.sorted().compactMap { day in
            let amount = Int(min(totals[day, default: 0] / stepsPerPep, stepPepDailyCap).rounded(.down))
            guard amount > 0 else { return nil }
            return Earning(
                sourceID: Self.stepsSourceID(for: day, calendar: calendar), day: day, amount: amount,
                rulesVersion: version)
        }
    }

    /// "steps:2026-11-11"
    public static func stepsSourceID(for day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "steps:%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func activityEarnings(
        for samples: [ActivitySample],
        since installDate: Date,
        calendar: Calendar
    ) -> [Earning] {
        var seen = Set<String>()
        let eligible =
            samples
            .filter { !$0.isUserEntered && $0.start >= installDate && $0.minutes > 0 }
            .sorted { ($0.start, $0.id) < ($1.start, $1.id) }
            .filter { seen.insert($0.id).inserted }

        // Rounding is applied to each day's running total, not to each sample, so many tiny
        // samples (Apple logs exercise minutes one at a time) add up to the true total instead
        // of each 0.6 Pep minute rounding up to 1.
        var rawTotals: [Date: Double] = [:]
        var paidTotals: [Date: Double] = [:]
        return eligible.map { sample in
            let day = calendar.startOfDay(for: sample.start)
            let rawBefore = rawTotals[day, default: 0]
            let raw = rawPep(for: sample)
            let underCap = max(0, min(raw, dailySoftCap - rawBefore))
            let overCap = raw - underCap
            rawTotals[day] = rawBefore + raw

            let paidBefore = paidTotals[day, default: 0]
            let paidAfter = paidBefore + underCap + overCap * overCapRate
            paidTotals[day] = paidAfter
            let amount = paidAfter.rounded() - paidBefore.rounded()
            return Earning(sourceID: sample.id, day: day, amount: Int(amount), rulesVersion: version)
        }
    }
}
