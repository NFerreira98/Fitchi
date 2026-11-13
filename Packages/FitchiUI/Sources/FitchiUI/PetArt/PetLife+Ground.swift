import FitchiCore
import Foundation

/// A footfall on the ground: where it landed and how long ago. The stage draws a footprint in
/// snow and sand, or a puff of dust on grass.
public struct Footstep: Hashable, Sendable {
    /// Across the ground, −1…1, like `PetFrame.x`.
    public var x: Double
    /// Front to back, like `PetFrame.depth`.
    public var depth: Double
    /// −1 left foot, 1 right foot.
    public var foot: Double
    /// Seconds since it landed.
    public var age: Double
}

extension PetLife {
    /// One footfall per bounce of the walk (`walk(_:stride:)` bounces at 1.9 Hz).
    static let stepEvery: TimeInterval = 1 / 1.9

    /// The steps of recent strolls, newest last: every footfall that landed within `lasting`
    /// seconds of `time`. Like everything else here, found from time alone.
    public static func trail(at time: TimeInterval, seed: Int, mood: PetMood, lasting: TimeInterval) -> [Footstep] {
        guard !mood.isAsleep, lasting > 0 else { return [] }
        let index = Int((time / slot).rounded(.down))
        let reach = Int((lasting / slot).rounded(.up))
        var steps: [Footstep] = []
        for past in (index - reach)...index where strolls(in: past, seed: seed, mood: mood) {
            let start = Double(past) * slot
            let begin = position(at: start + 0.0001, seed: seed, mood: mood)
            let end = position(at: start + slot - 0.0001, seed: seed, mood: mood)
            let duration = strollDuration(across: end.x - begin.x, back: end.depth - begin.depth, mood: mood)
            for count in 1..<max(2, Int(duration / stepEvery) + 1) {
                let landed = start + Double(count) * stepEvery
                let age = time - landed
                guard landed < start + duration, age >= 0, age < lasting else { continue }
                let progress = (landed - start) / duration
                let eased = progress * progress * (3 - 2 * progress)
                steps.append(
                    Footstep(
                        x: begin.x + (end.x - begin.x) * eased, depth: begin.depth + (end.depth - begin.depth) * eased,
                        foot: count.isMultiple(of: 2) ? 1 : -1, age: age))
            }
        }
        return steps
    }
}
