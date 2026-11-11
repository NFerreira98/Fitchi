import Foundation

/// The free egg every new player gets on first launch. It hatches into a random common
/// starter once the player has moved for a few minutes, or by the next morning at the latest,
/// so nobody gets stuck on day one.
public struct StarterEgg: Codable, Hashable, Sendable {
    public var grantedAt: Date
    /// Set once hatched. The egg record stays around so it can't be granted twice.
    public var hatchedPetID: UUID?

    public init(grantedAt: Date, hatchedPetID: UUID? = nil) {
        self.grantedAt = grantedAt
        self.hatchedPetID = hatchedPetID
    }

    public var isHatched: Bool { hatchedPetID != nil }
}

/// How far an egg is from hatching.
public struct HatchProgress: Hashable, Sendable {
    public var activeMinutes: Double
    public var requiredMinutes: Double
    /// The egg hatches by itself from this moment, even without activity.
    public var fallbackDate: Date
    public var isReady: Bool

    public var fraction: Double { min(1, activeMinutes / max(1, requiredMinutes)) }
    public var minutesRemaining: Int { Int(max(0, requiredMinutes - activeMinutes).rounded(.up)) }
}

public struct HatchRules: Hashable, Sendable {
    /// Active minutes (workouts or exercise minutes) after the egg was granted.
    public var requiredMinutes: Double
    /// The fallback hatch is the first `fallbackHour`:00 at least `minimumWait` after granting.
    public var fallbackHour: Int
    public var minimumWait: TimeInterval
    /// Newborn pets start with every stat full.
    public var newbornStatValue: Double

    public static let v1 = HatchRules(
        requiredMinutes: 5, fallbackHour: 7, minimumWait: 6 * .hour, newbornStatValue: 100)

    public func fallbackDate(for egg: StarterEgg, calendar: Calendar) -> Date {
        let earliest = egg.grantedAt.addingTimeInterval(minimumWait)
        return calendar.nextDate(
            after: earliest.addingTimeInterval(-1),
            matching: DateComponents(hour: fallbackHour, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? earliest
    }

    /// Minutes of real (not hand-entered) activity after the egg was granted. Expects samples
    /// with overlaps already resolved, as `HealthDataSource` returns them.
    public func activeMinutes(for egg: StarterEgg, samples: [ActivitySample]) -> Double {
        samples
            .filter { !$0.isUserEntered && $0.end > egg.grantedAt }
            .reduce(0) { total, sample in
                total + sample.end.timeIntervalSince(max(sample.start, egg.grantedAt)) / 60
            }
    }

    public func progress(
        for egg: StarterEgg,
        samples: [ActivitySample],
        at date: Date,
        calendar: Calendar
    ) -> HatchProgress {
        let minutes = activeMinutes(for: egg, samples: samples)
        let fallback = fallbackDate(for: egg, calendar: calendar)
        return HatchProgress(
            activeMinutes: minutes,
            requiredMinutes: requiredMinutes,
            fallbackDate: fallback,
            isReady: !egg.isHatched && (minutes >= requiredMinutes || date >= fallback)
        )
    }
}

/// Rules for names players type in.
public enum PetName {
    public static let maxLength = 16

    /// Trimmed and shortened, or nil if nothing usable is left.
    public static func sanitized(_ raw: String) -> String? {
        let collapsed = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let trimmed = String(collapsed.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
