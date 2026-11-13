import FitchiCore
import Foundation

/// Little habits that show who a pet is. Now and then, while standing about, a pet does its
/// personality's thing: an easygoing pet hums, a glutton sniffs for snacks, a couch potato
/// stretches and flops, a neat freak tidies itself, a hyper pet does zoomies and a picky eater
/// turns its nose up.
extension PetLife {
    /// About one resting slot in three.
    static let habitChance = 0.3
    static let habitLength: TimeInterval = 2.6

    /// Seconds into a habit at `time`, if one is playing.
    static func habit(at time: TimeInterval, seed: Int, mood: PetMood) -> TimeInterval? {
        let index = Int((time / slot).rounded(.down))
        guard !mood.isDown, !mood.isAsleep, !strolls(in: index, seed: seed, mood: mood),
            !isNapping(in: index, seed: seed, mood: mood), noise(seed &+ 8, index) < habitChance,
            visit(at: time, seed: seed, mood: mood) == nil
        else { return nil }
        let start = 1.2 + noise(seed &+ 9, index) * 2.2
        let elapsed = time - Double(index) * slot - start
        return elapsed >= 0 && elapsed < habitLength ? elapsed : nil
    }

    static func perform(_ personality: Personality, elapsed: TimeInterval, on frame: inout PetFrame) {
        var pose = frame.pose
        let envelope = sin(.pi * min(1, elapsed / habitLength))
        switch personality {
        case .easygoing:
            // Hums to itself, swaying with its eyes shut.
            pose.eyesOpen = 0
            pose.smile = 1
            pose.tilt += sin(elapsed * 2 * .pi / 1.3) * 6 * envelope
            pose.mouthOpen = 0.15 + 0.15 * abs(sin(elapsed * 5))
        case .glutton:
            // Nose down, sniffing about for crumbs and licking its lips.
            pose.lookY = 0.8
            pose.lookX = sin(elapsed * 4) * 0.8
            pose.headBob += 2 * envelope
            pose.mouthOpen = abs(sin(elapsed * 9)) * 0.4
            pose.tailAngle = sin(elapsed * 2 * .pi / 0.35) * 10
        case .couchPotato:
            stretchAndFlop(elapsed: elapsed, on: &pose)
        case .neatFreak:
            tidy(elapsed: elapsed, on: &frame, pose: &pose)
        case .hyper:
            // Zoomies on the spot: quick hops, turning this way and that.
            let hop = 0.43
            pose.lift += abs(sin(elapsed * .pi / hop)) * 9 * envelope
            if Int(elapsed / hop).isMultiple(of: 2) { pose.flipped.toggle() }
            pose.mouthOpen = 0.8
            pose.tailAngle = sin(elapsed * 2 * .pi / 0.2) * 16
            pose.earAngle = sin(elapsed * 2 * .pi / 0.3) * 10
        case .pickyEater:
            // Nose in the air, eyes half shut, looking away: hmph.
            if elapsed > 0.3 { pose.flipped.toggle() }
            pose.lookX = 0.6
            pose.lookY = -0.9
            pose.eyesOpen = 0.35
            pose.smile = 0
            pose.headBob -= 1.5 * envelope
        }
        frame.pose = pose
    }

    /// A long stretch up with a yawn, then a contented flop.
    static func stretchAndFlop(elapsed: TimeInterval, on pose: inout PetPose) {
        if elapsed < 1.2 {
            let stretch = sin(.pi * elapsed / 1.2)
            pose.squash = -0.18 * stretch
            pose.mouthOpen = stretch
            pose.eyesOpen = 0
        } else {
            let flop = sin(.pi * (elapsed - 1.2) / (habitLength - 1.2))
            pose.squash = 0.15 * flop
            pose.lift = 0
            pose.eyesOpen = 0.4
            pose.smile = 0.6
        }
    }

    /// A quick shake to straighten its fur, then a squeaky-clean twinkle.
    static func tidy(elapsed: TimeInterval, on frame: inout PetFrame, pose: inout PetPose) {
        pose.eyesOpen = 0
        if elapsed > 0.3, elapsed < 1.3 {
            let shake = sin(elapsed * 2 * .pi * 5)
            pose.tilt = shake * 5 * sin(.pi * (elapsed - 0.3))
            pose.earAngle = shake * 12
        } else if elapsed >= 1.3 {
            frame.effects.prop = .sparkle(min(1, (elapsed - 1.3) / 1.1))
            pose.smile = 1
        }
    }
}
