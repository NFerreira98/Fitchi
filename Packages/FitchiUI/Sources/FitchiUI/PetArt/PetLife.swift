import FitchiCore
import Foundation

/// One moment of a living pet: how it's posed, what's drawn around it and where it stands.
public struct PetFrame: Hashable, Sendable {
    public var pose = PetPose()
    public var effects = PetEffects()
    /// Where the pet stands across its patch of ground, −1 (left) … 1 (right).
    public var x: Double = 0
    /// How far back on the ground the pet is: 0 = the back (near the horizon, smaller),
    /// 1 = the front (nearest, full size). Stages without depth ignore it.
    public var depth: Double = 0.5
    /// A butterfly (or bird, or firefly) dropping by, which the pet is watching.
    public var visitor: Visitor?

    public init() {}
}

/// What a pet does from moment to moment: wandering, idling, catnaps, sleeping through the night,
/// showing its needs and acting out care.
///
/// Like the stats, behaviour is a pure function of time (plus a per-pet seed), never stored state:
/// the same moment always looks the same, nothing needs a timer, and two pets never move in sync.
public enum PetLife {
    /// A care moment being acted out.
    public struct Reaction: Hashable, Sendable {
        /// nil for a generic happy wiggle.
        public var action: CareAction?
        public var startedAt: TimeInterval

        public init(action: CareAction?, startedAt: TimeInterval) {
            self.action = action
            self.startedAt = startedAt
        }

        public var duration: TimeInterval { PetLife.duration(of: action) }
    }

    public static func duration(of action: CareAction?) -> TimeInterval {
        switch action {
        case .feed, .play, .wash: 2.8
        case .rest: 4
        case nil: 1.6
        }
    }

    /// Seconds per behaviour slot: in each slot the pet either strolls somewhere or stays put.
    static let slot: TimeInterval = 6.5
    /// Slots per nap window; a daytime catnap fills the last `napSlots` of a window.
    static let napWindow = 12
    static let napSlots = 4

    /// - Parameters:
    ///   - wander: false keeps the pet in the middle (hatching, small previews).
    ///   - still: Reduce Motion. The pet stays put and only changes expression.
    ///   - visitors: whether little creatures drop by now and then (outdoor scenes).
    ///   - cues: a hello when you come back, a boop or a pat, the glow after a workout.
    ///   - personality: gives the pet its little habits while it stands about.
    public static func frame(
        at time: TimeInterval, seed: Int, mood: PetMood, reaction: Reaction? = nil, wander: Bool = true,
        still: Bool = false, visitors: Bool = false, cues: Cues = Cues(), personality: Personality? = nil
    ) -> PetFrame {
        var frame = PetFrame()
        let clock = still ? 0 : time
        frame.effects.clock = clock

        if let reaction, time - reaction.startedAt < reaction.duration, time >= reaction.startedAt {
            if wander && !still {
                let place = position(at: reaction.startedAt, seed: seed, mood: mood)
                frame.x = place.x
                frame.depth = place.depth
            } else {
                frame.x = 0
            }
            frame.pose = PetPose.idle(at: clock, seed: Double(seed % 1000) / 25)
            act(reaction, elapsed: still ? reaction.duration / 2 : time - reaction.startedAt, still: still, on: &frame)
            return frame
        }

        if mood.isAsleep {
            sleep(&frame, amount: 1, clock: clock)
            showNeeds(mood, clock: clock, asleep: true, on: &frame)
            stir(cues, at: time, on: &frame)
            return frame
        }

        if let greeting = cues.greeting, wander, !still,
            let big = bigGreeting(greeting, at: time, seed: seed, mood: mood, clock: clock)
        {
            return big
        }

        frame.pose = still ? PetPose() : PetPose.idle(at: clock, seed: Double(seed % 1000) / 25)
        if wander && !still {
            let place = position(at: time, seed: seed, mood: mood)
            frame.x = place.x
            frame.depth = place.depth
            frame.pose.flipped = place.facingRight
            if let stride = place.stride { walk(&frame.pose, stride: stride) }
            let nap = napAmount(at: time, seed: seed, mood: mood)
            if nap > 0 {
                sleep(&frame, amount: nap, clock: clock)
                showNeeds(mood, clock: clock, asleep: nap > 0.5, on: &frame)
                stir(cues, at: time, on: &frame)
                return frame
            }
        }
        express(mood, clock: still ? 0 : time, seed: seed, on: &frame)
        showNeeds(mood, clock: clock, asleep: false, on: &frame)
        if wander, !still {
            standAbout(at: time, seed: seed, mood: mood, visitors: visitors, personality: personality, on: &frame)
        }
        respond(to: cues, at: time, seed: seed, mood: mood, still: still, on: &frame)
        return frame
    }

    /// While standing about: watch a visitor drop by, or do a little personality habit.
    static func standAbout(
        at time: TimeInterval, seed: Int, mood: PetMood, visitors: Bool, personality: Personality?,
        on frame: inout PetFrame
    ) {
        if visitors, let visitor = visit(at: time, seed: seed, mood: mood) {
            watch(visitor, on: &frame)
        } else if let personality, let elapsed = habit(at: time, seed: seed, mood: mood) {
            perform(personality, elapsed: elapsed, on: &frame)
        }
    }

    // MARK: - Wandering

    struct Place {
        var x: Double
        var depth: Double = 0.5
        var facingRight: Bool
        /// Seconds into a walk, while walking.
        var stride: Double?
    }

    /// Where the pet is at `time`. Each slot either starts a stroll to a new spot or stays; the
    /// spot is found by looking back to the most recent stroll.
    static func position(at time: TimeInterval, seed: Int, mood: PetMood) -> Place {
        let index = Int((time / slot).rounded(.down))
        let into = time - Double(index) * slot
        let lookBack = 16
        // Spots for the recent past, oldest first, so each stroll knows where it starts.
        var spot = 0.0
        var depth = 0.5
        var facingRight = false
        var walkFrom = 0.0
        var depthFrom = 0.5
        for past in (index - lookBack)...index {
            guard strolls(in: past, seed: seed, mood: mood) else { continue }
            let target = noise(seed &+ 1, past) * 2 - 1
            walkFrom = spot
            depthFrom = depth
            facingRight = target > spot
            spot = target
            // Each stroll also heads somewhere new front-to-back, so the pet roams the ground.
            depth = noise(seed &+ 2, past)
        }
        guard strolls(in: index, seed: seed, mood: mood) else {
            return Place(x: spot, depth: depth, facingRight: facingRight)
        }
        let duration = strollDuration(across: spot - walkFrom, back: depth - depthFrom, mood: mood)
        guard into < duration else { return Place(x: spot, depth: depth, facingRight: facingRight) }
        let progress = into / duration
        let eased = progress * progress * (3 - 2 * progress)
        return Place(
            x: walkFrom + (spot - walkFrom) * eased, depth: depthFrom + (depth - depthFrom) * eased,
            facingRight: facingRight, stride: into)
    }

    /// How long a stroll takes, from how far it goes across and front to back.
    static func strollDuration(across: Double, back: Double, mood: PetMood) -> Double {
        let speed = mood.isDown || mood.isTired ? 0.22 : 0.4
        let distance = (across * across + back * 1.2 * back * 1.2).squareRoot()
        return min(slot - 0.5, max(1.2, distance / speed))
    }

    static func strolls(in index: Int, seed: Int, mood: PetMood) -> Bool {
        if isNapping(in: index, seed: seed, mood: mood) { return false }
        let chance = mood.isDown || mood.isTired ? 0.3 : (mood.isThriving ? 0.6 : 0.48)
        return noise(seed, index) < chance
    }

    /// A waddle: a little bounce on each step and a side-to-side lean, looking where it's going.
    static func walk(_ pose: inout PetPose, stride: Double) {
        let step = sin(.pi * 1.9 * stride)
        pose.lift += abs(step) * 2.4
        pose.tilt += step * 5
        pose.lookX = -0.9  // Mirrored when walking right, so this always looks ahead.
        pose.lookY = 0
        pose.tailAngle += step * 10
        pose.earAngle += step * 6
    }

    // MARK: - Sleep

    static func isNapping(in index: Int, seed: Int, mood: PetMood) -> Bool {
        let window = Int((Double(index) / Double(napWindow)).rounded(.down))
        let position = index - window * napWindow
        guard position >= napWindow - napSlots else { return false }
        return noise(seed &+ 2, window) < (mood.isTired ? 0.6 : 0.12)
    }

    /// 0 awake … 1 asleep, easing in and out of a daytime catnap.
    static func napAmount(at time: TimeInterval, seed: Int, mood: PetMood) -> Double {
        let index = Int((time / slot).rounded(.down))
        guard isNapping(in: index, seed: seed, mood: mood) else { return 0 }
        let window = Int((Double(index) / Double(napWindow)).rounded(.down))
        let napStart = Double(window * napWindow + napWindow - napSlots) * slot
        let elapsed = time - napStart
        let total = Double(napSlots) * slot
        return min(1, elapsed / 1.2, (total - elapsed) / 1.2)
    }

    static func sleep(_ frame: inout PetFrame, amount: Double, clock: Double) {
        let breath = sin(clock * 2 * .pi / 4.6)
        var pose = frame.pose
        pose.sleep = amount
        pose.squash = breath * 0.035 * amount + pose.squash * (1 - amount)
        pose.headBob = breath * 0.6
        pose.eyesOpen = amount > 0.5 ? 0 : 1 - amount * 2
        pose.mouthOpen = 0
        pose.smile = 0.6
        pose.lift = 0
        pose.tilt = 0
        pose.tailAngle *= 1 - amount
        pose.earAngle = -4 * amount
        frame.pose = pose
        frame.effects.zzz = amount > 0.5
    }

    // MARK: - Moods

    /// Faces and body language for how the pet feels.
    static func express(_ mood: PetMood, clock: Double, seed: Int, on frame: inout PetFrame) {
        var pose = frame.pose
        let offset = Double(seed % 97)
        if mood.isDown {
            pose.smile = mood.condition == .sad ? -0.6 : -1
            pose.worry = mood.condition == .sad ? 0.7 : 1
            pose.headBob += 1.5
            pose.eyesOpen = min(pose.eyesOpen, 0.8)
            pose.tailAngle *= 0.4
        } else if mood.isHungry || mood.isBored {
            pose.smile = 0
            pose.worry = 0.3
        }
        if mood.isTired {
            pose.eyesOpen = min(pose.eyesOpen, 0.55)
            // A big yawn every 11 s.
            let yawn = (clock + offset).truncatingRemainder(dividingBy: 11)
            if yawn < 1.4 {
                let open = sin(.pi * yawn / 1.4)
                pose.mouthOpen = open
                pose.eyesOpen = open > 0.4 ? 0 : pose.eyesOpen
                pose.lift = 0
            }
        }
        if mood.isThriving, pose.tilt == 0 {
            // A happy hop every 9 s, and a puff of hearts every 18 s.
            let beat = (clock + offset).truncatingRemainder(dividingBy: 9)
            if beat < 0.6 {
                pose.lift += sin(.pi * beat / 0.6) * 7
                pose.eyesOpen = 0
                pose.mouthOpen = 0.7
            }
            let puff = (clock + offset).truncatingRemainder(dividingBy: 18)
            if puff < 1.6 { frame.effects.hearts = puff / 1.6 }
        }
        frame.pose = pose
    }

    /// Signs of what the pet needs: stink lines when dirty, a thought bubble for food or play.
    static func showNeeds(_ mood: PetMood, clock: Double, asleep: Bool, on frame: inout PetFrame) {
        frame.effects.stink = mood.isDirty
        frame.effects.smudges = mood.isDirty
        frame.effects.sweat = mood.condition == .sick || mood.condition == .packing
        guard !asleep else { return }
        // The bubble shows for 4 s of every 9, alternating when it wants both.
        let wants = [mood.isHungry ? CareAction.feed : nil, mood.isBored ? .play : nil].compactMap { $0 }
        guard !wants.isEmpty else { return }
        let cycle = Int((clock / 9).rounded(.down))
        let into = clock - Double(cycle) * 9
        if into < 4 || clock == 0 {
            frame.effects.thought = wants[abs(cycle) % wants.count].emoji
        }
    }

}

extension PetLife {
    // MARK: - Care

    static func act(_ reaction: Reaction, elapsed: Double, still: Bool, on frame: inout PetFrame) {
        var pose = frame.pose
        let progress = min(1, max(0, elapsed / reaction.duration))
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
            let amount = still ? 1 : min(1, elapsed / 0.5, (reaction.duration - elapsed) / 0.6)
            sleep(&frame, amount: amount, clock: elapsed)
            return
        case nil:
            pose.eyesOpen = 0
            pose.mouthOpen = 0.8
            pose.lift = still ? 0 : abs(sin(elapsed * 2 * .pi / 0.5)) * 4
        }
        frame.pose = pose
    }

    // MARK: - Noise

    /// A stable pseudo-random number in 0..<1 for a pair of integers (SplitMix64).
    static func noise(_ seed: Int, _ index: Int) -> Double {
        var value = UInt64(bitPattern: Int64(seed)) &* 0x9E37_79B9_7F4A_7C15 &+ UInt64(bitPattern: Int64(index))
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        value ^= value >> 31
        return Double(value >> 11) / Double(UInt64(1) << 53)
    }
}

public extension PetLife {
    /// A stable behaviour seed for a pet.
    static func seed(for id: UUID?) -> Int {
        guard let id else { return 0 }
        return Int(id.uuid.0) << 16 | Int(id.uuid.1) << 8 | Int(id.uuid.2)
    }
}
