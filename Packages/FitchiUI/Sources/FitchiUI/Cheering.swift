import FitchiCore
import Foundation
import Observation

/// Which milestones this device has already cheered (or announced). Kept per device in
/// UserDefaults: each app celebrates once, and nothing about it needs syncing.
public struct CheerLog: Sendable {
    /// The pet has cheered it on screen.
    public static let cheered = CheerLog(key: "fitchi.cheered")
    /// A notification has gone out for it (watch, while the app was in the background).
    public static let announced = CheerLog(key: "fitchi.cheerAnnounced")

    let key: String
    /// Plenty for a few days of milestones; older ids fall off the front.
    static let keep = 120

    public var ids: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }

    public func mark(_ ids: [String]) {
        var list = UserDefaults.standard.stringArray(forKey: key) ?? []
        for id in ids where !list.contains(id) { list.append(id) }
        UserDefaults.standard.set(Array(list.suffix(Self.keep)), forKey: key)
    }
}

extension Milestone {
    /// "10,000 steps! Maple is cheering you on! 🎉"
    public func message(petName: String) -> String {
        switch kind {
        case .steps(let steps): "\(steps.formatted()) steps! \(petName) is cheering you on! 🎉"
        case .activeMinutes(let minutes): "\(minutes) active minutes! \(petName) is so proud! 🔥"
        case .workout(_, let minutes): "\(minutes)-minute workout done! \(petName) is cheering! 💪"
        case .pepGoal: "Daily Pep goal reached! \(petName) is over the moon! ✦"
        }
    }

    /// For a notification: "10,000 steps!"
    public var headline: String {
        switch kind {
        case .steps(let steps): "\(steps.formatted()) steps!"
        case .activeMinutes(let minutes): "\(minutes) active minutes!"
        case .workout(_, let minutes): "\(minutes)-minute workout done!"
        case .pepGoal: "Daily Pep goal reached!"
        }
    }
}

extension Cheers {
    /// Today's milestones from what an app has at hand.
    public static func reached(
        at now: Date, samples: [ActivitySample], steps: [StepCount], today: DailySummary, pepGoal: Int
    ) -> [Milestone] {
        reached(at: now, samples: samples, steps: steps, pepGoal: pepGoal, pepEarned: today.pepEarned)
    }
}

/// A milestone the pet is celebrating on screen right now.
public struct ActiveCheer: Equatable, Sendable {
    public let milestone: Milestone
    public let startedAt: Date
}

/// Watches for milestones while the pet is on screen: after each activity refresh, the newest one
/// this device hasn't cheered yet makes the pet celebrate.
@Observable
@MainActor
public final class CheerBoard {
    public private(set) var current: ActiveCheer?
    private let log: CheerLog

    public init(log: CheerLog = .cheered) {
        self.log = log
    }

    /// How long a cheer holds the stage.
    public static let showsFor: Duration = .seconds(3.5)

    public func check(at now: Date, samples: [ActivitySample], steps: [StepCount], today: DailySummary, pepGoal: Int) {
        guard current == nil else { return }
        let reached = Cheers.reached(at: now, samples: samples, steps: steps, today: today, pepGoal: pepGoal)
        guard let next = Cheers.next(in: reached, cheered: log.ids) else { return }
        // Everything reached so far counts as cheered: one celebration for a batch, not a parade.
        log.mark(reached.map(\.id))
        current = ActiveCheer(milestone: next, startedAt: now)
    }

    public func finish() {
        current = nil
    }
}
