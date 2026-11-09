import Foundation

/// Source of "now" for all game rules.
///
/// Pet stats are computed from timestamps (`now − lastFedAt`) rather than ticked by timers,
/// so every rule that depends on time takes a `GameClock`. Production uses `SystemClock`;
/// tests use `FixedClock` to get deterministic results.
public protocol GameClock: Sendable {
    var now: Date { get }
}

/// The real wall clock.
public struct SystemClock: GameClock {
    public init() {}
    public var now: Date { Date() }
}

/// A clock pinned to a specific instant. Use in tests and previews.
public struct FixedClock: GameClock {
    public let now: Date

    public init(_ now: Date) {
        self.now = now
    }

    /// Returns a new clock moved forward by `interval` seconds.
    public func advanced(by interval: TimeInterval) -> FixedClock {
        FixedClock(now.addingTimeInterval(interval))
    }
}
