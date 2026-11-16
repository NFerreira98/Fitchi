import FitchiCore
import Foundation

/// The small things a pet does while just standing there: an ear flick, a swish of the tail, a
/// look around, a glance at you, a sniff, a shift of its weight, a stretch, a scratch, a sigh.
/// One or two a slot, picked and timed from the clock like everything else, so it never looks
/// like a loop.
extension PetLife {
    enum Fidget: Int, CaseIterable {
        case earFlick, tailSwish, lookAround, glanceAtYou, sniff, shiftWeight, stretch, scratch, sigh
        /// Only a bored pet does this: kicks at the ground.
        case scuff

        var duration: TimeInterval {
            switch self {
            case .earFlick: 0.4
            case .tailSwish: 1.4
            case .lookAround: 2.4
            case .glanceAtYou: 1.6
            case .sniff: 1.3
            case .shiftWeight: 0.9
            case .stretch: 1.5
            case .scratch: 1.1
            case .sigh: 1.4
            case .scuff: 1.2
            }
        }
    }

    /// The fidget playing at `time` and how far into it the pet is, if one is.
    static func fidget(at time: TimeInterval, seed: Int, mood: PetMood) -> (kind: Fidget, elapsed: TimeInterval)? {
        let index = Int((time / slot).rounded(.down))
        guard !mood.isAsleep, !strolls(in: index, seed: seed), !isNapping(in: index, seed: seed, mood: mood) else {
            return nil
        }
        let into = time - Double(index) * slot
        // Up to two a slot: one in the first half, one in the second.
        for pick in 0..<2 {
            let salt = 20 + pick * 3
            guard noise(seed &+ salt, index) < 0.85 else { continue }
            var kind = Fidget.allCases[Int(noise(seed &+ salt + 1, index) * Double(Fidget.allCases.count - 1))]
            if mood.isBored, noise(seed &+ salt + 2, index) < 0.4 { kind = .scuff }
            if mood.isDown, kind == .glanceAtYou || kind == .stretch { kind = .sigh }
            let half = slot / 2
            let start = Double(pick) * half + 0.2 + noise(seed &+ salt + 2, index) * (half - kind.duration - 0.3)
            let elapsed = into - start
            if elapsed >= 0, elapsed < kind.duration { return (kind, elapsed) }
        }
        return nil
    }

    static func fidget(at time: TimeInterval, seed: Int, mood: PetMood, on frame: inout PetFrame) {
        guard let (kind, elapsed) = fidget(at: time, seed: seed, mood: mood) else { return }
        perform(kind, elapsed: elapsed, on: &frame)
    }

    static func perform(_ kind: Fidget, elapsed: TimeInterval, on frame: inout PetFrame) {
        var pose = frame.pose
        let progress = elapsed / kind.duration
        let envelope = sin(.pi * progress)
        switch kind {
        case .earFlick:
            pose.earAngle += sin(.pi * progress * 2) * 14
        case .tailSwish:
            pose.tailAngle = sin(.pi * progress) * 24
        case .lookAround:
            pose.lookX = sin(2 * .pi * progress) * 0.95
            pose.lookY = -0.2
            pose.earAngle += sin(2 * .pi * progress) * 4
        case .glanceAtYou:
            pose.lookX = 0
            pose.lookY = 0.35
            pose.smile = max(pose.smile, 0.9)
            pose.tilt += sin(.pi * progress) * 3
        case .sniff:
            pose.lookY = 0.9
            pose.lookX = 0
            pose.headBob += 2.6 * envelope
            pose.mouthOpen = max(pose.mouthOpen, 0.15 * abs(sin(elapsed * 18)))
            pose.earAngle += 3 * envelope
        case .shiftWeight:
            pose.squash += 0.05 * envelope
            pose.tilt += 2.5 * sin(.pi * progress)
        case .stretch:
            pose.squash -= 0.14 * envelope
            pose.mouthOpen = max(pose.mouthOpen, 0.5 * envelope)
            if envelope > 0.5 { pose.eyesOpen = 0 }
        case .scratch:
            let scrub = sin(elapsed * 2 * .pi * 7)
            pose.tilt += scrub * 4 * envelope
            pose.earAngle += scrub * 10 * envelope
            pose.eyesOpen = min(pose.eyesOpen, 0.5)
        case .sigh:
            pose.mouthOpen = max(pose.mouthOpen, 0.3 * envelope)
            pose.headBob += 2 * envelope
            pose.squash += 0.04 * envelope
            pose.eyesOpen = min(pose.eyesOpen, 0.6)
        case .scuff:
            pose.lookY = 0.8
            pose.lookX = 0.3
            pose.tilt += 3 * sin(.pi * progress)
            frame.effects.scuff = progress
        }
        frame.pose = pose
    }
}
