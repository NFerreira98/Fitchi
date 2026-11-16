import FitchiCore
import Foundation

extension PetLife {
    // MARK: - Care

    /// Where care happens: near the front, a little towards the side the pet was on, so it
    /// comes to you rather than the bowl or ball turning up wherever it stood.
    static func careSpot(from place: Place) -> (x: Double, depth: Double) {
        (place.x * 0.3, 0.88)
    }

    /// Where the pet is when not busy: wandering by day, curled up in the middle at night.
    static func restingPlace(at time: TimeInterval, seed: Int, mood: PetMood) -> Place {
        mood.isAsleep ? Place(x: 0, depth: 0.5, facingRight: false) : position(at: time, seed: seed)
    }

    /// A care moment on a wandering stage: trot over to the front, act it out there, then stroll
    /// back to wherever its wandering would have it by now. No jumps at either end.
    static func careFrame(
        _ reaction: Reaction, elapsed: TimeInterval, seed: Int, mood: PetMood, clock: Double
    ) -> PetFrame {
        var frame = PetFrame()
        frame.effects.clock = clock
        frame.pose = PetPose.idle(at: clock, seed: Double(seed % 1000) / 25)
        let start = restingPlace(at: reaction.startedAt, seed: seed, mood: mood)
        let end = restingPlace(at: reaction.endsAt, seed: seed, mood: mood)
        let spot = careSpot(from: start)
        let acting = actDuration(of: reaction.action)
        func move(
            from origin: (x: Double, depth: Double), to target: (x: Double, depth: Double), progress: Double,
            stride: Double
        ) {
            let eased = SceneLight.smooth(progress)
            frame.x = origin.x + (target.x - origin.x) * eased
            frame.depth = origin.depth + (target.depth - origin.depth) * eased
            frame.pose.flipped = target.x > origin.x
            // Already there (or nearly): it just turns, no walking on the spot.
            if abs(target.x - origin.x) + abs(target.depth - origin.depth) > 0.05 { walk(&frame.pose, stride: stride) }
        }
        if elapsed < careApproach {
            move(
                from: (start.x, start.depth), to: spot, progress: elapsed / careApproach, stride: elapsed * 1.5)
            // Eager: ears up, mouth open, looking where it's going.
            frame.pose.mouthOpen = 0.5
            frame.pose.earAngle += 6
        } else if elapsed < careApproach + acting {
            frame.x = spot.x
            frame.depth = spot.depth
            act(reaction, elapsed: elapsed - careApproach, still: false, on: &frame)
        } else {
            let into = elapsed - careApproach - acting
            move(from: spot, to: (end.x, end.depth), progress: into / careReturn, stride: into)
            // Content after being looked after.
            frame.pose.smile = max(frame.pose.smile, 0.8)
        }
        showNeeds(mood, clock: clock, asleep: false, on: &frame)
        return frame
    }

    static func act(_ reaction: Reaction, elapsed: Double, still: Bool, on frame: inout PetFrame) {
        var pose = frame.pose
        let length = actDuration(of: reaction.action)
        let progress = min(1, max(0, elapsed / length))
        switch reaction.action {
        case .feed:
            let eating = min(1, max(0, (elapsed - 0.4) / 1.9))
            frame.effects.prop = .bowl(eaten: eating)
            pose.headBob += 2.5
            pose.lookX = 0
            pose.lookY = 1
            if eating > 0, eating < 1, !still {
                pose.mouthOpen = abs(sin(elapsed * 2 * .pi * 2.4))
                pose.eyesOpen = 0
            } else if eating >= 1 {
                pose.eyesOpen = 0
                pose.mouthOpen = 0.5
                frame.effects.hearts = (elapsed - 2.3) / 0.5
            }
        case .play:
            let bounce = abs(sin(elapsed * .pi * 2.2))
            let ball = CGPoint(x: 14 + 72 * progress, y: 88 - bounce * 44)
            frame.effects.prop = .ball(ball)
            pose.lookX = max(-1, min(1, (ball.x - 50) / 25))
            pose.lookY = ball.y < 60 ? -0.8 : 0.3
            pose.lift = still ? 0 : abs(sin(elapsed * .pi * 2.2 + 0.7)) * 7
            pose.mouthOpen = 0.7
            pose.tailAngle = sin(elapsed * 2 * .pi / 0.3) * 14
        case .wash:
            frame.effects.prop = elapsed < 2 ? .bubbles(elapsed / 2) : .sparkle((elapsed - 2) / 0.8)
            pose.eyesOpen = 0
            pose.mouthOpen = 0.4
            if elapsed > 0.9, elapsed < 1.9, !still {
                // Shake it off.
                pose.tilt = sin(elapsed * 2 * .pi * 6) * 7 * sin(.pi * (elapsed - 0.9))
                pose.earAngle = sin(elapsed * 2 * .pi * 6) * 12
            }
        case .rest:
            frame.pose = pose
            let amount = still ? 1 : min(1, elapsed / 0.5, (length - elapsed) / 0.6)
            sleep(&frame, amount: amount, clock: elapsed)
            return
        case nil:
            pose.eyesOpen = 0
            pose.mouthOpen = 0.8
            pose.lift = still ? 0 : abs(sin(elapsed * 2 * .pi / 0.5)) * 4
        }
        frame.pose = pose
    }
}
