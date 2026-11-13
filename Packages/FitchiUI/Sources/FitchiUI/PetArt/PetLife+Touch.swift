import FitchiCore
import Foundation

extension PetLife {
    /// Things going on around the pet beyond its own routine: a hello, your finger, a workout.
    public struct Cues: Hashable, Sendable {
        public var greeting: Greeting?
        public var boop: Boop?
        /// How long the pet has been held (petted) so far, in seconds; nil when it isn't.
        public var pettedFor: Double?
        /// 0…1, how pumped it still is from your last workout (`Afterglow` in Core).
        public var afterglow: Double

        public init(greeting: Greeting? = nil, boop: Boop? = nil, pettedFor: Double? = nil, afterglow: Double = 0) {
            self.greeting = greeting
            self.boop = boop
            self.pettedFor = pettedFor
            self.afterglow = afterglow
        }
    }

    /// A tap on the pet. Each boop in a row gets a different reaction.
    public struct Boop: Hashable, Sendable {
        public var startedAt: TimeInterval
        /// Which reaction: a giggle, a spin, a blush or a surprised hop.
        public var variety: Int

        public init(startedAt: TimeInterval, variety: Int) {
            self.startedAt = startedAt
            self.variety = variety
        }

        public static let duration: TimeInterval = 1.1

        func elapsed(at time: TimeInterval) -> TimeInterval? {
            let elapsed = time - startedAt
            return elapsed >= 0 && elapsed < Self.duration ? elapsed : nil
        }
    }

    /// An awake pet's response to the cues, layered over whatever it's doing.
    static func respond(
        to cues: Cues, at time: TimeInterval, seed: Int, mood: PetMood, still: Bool, on frame: inout PetFrame
    ) {
        if cues.afterglow > 0, !mood.isDown {
            pumped(cues.afterglow, clock: still ? 0 : time, seed: seed, on: &frame)
        }
        if let elapsed = cues.greeting?.elapsed(at: time) {
            greet(elapsed: still ? 0.3 : elapsed, on: &frame.pose)
        }
        if let held = cues.pettedFor {
            petted(for: still ? 1 : held, on: &frame)
        }
        if let boop = cues.boop, let elapsed = boop.elapsed(at: time) {
            booped(boop.variety, elapsed: still ? 0.5 : elapsed, still: still, on: &frame)
        }
    }

    /// A sleeping pet only stirs: eyes flutter half open, then it settles back down.
    static func stir(_ cues: Cues, at time: TimeInterval, on frame: inout PetFrame) {
        let booped = cues.boop?.elapsed(at: time).map { sin(.pi * $0 / Boop.duration) } ?? 0
        let petted = cues.pettedFor.map { min(1, $0 / 0.5) * 0.6 } ?? 0
        let stirring = max(booped, petted)
        guard stirring > 0 else { return }
        frame.pose.eyesOpen = max(frame.pose.eyesOpen, booped * 0.35)
        frame.pose.smile = 0.6 + 0.4 * stirring
        frame.pose.earAngle += stirring * 6 * sin(time * 9)
    }

    /// The reactions to a boop.
    static func booped(_ variety: Int, elapsed: Double, still: Bool, on frame: inout PetFrame) {
        let progress = elapsed / Boop.duration
        let arc = sin(.pi * progress)
        var pose = frame.pose
        pose.worry = 0
        pose.smile = 1
        pose.lookX = 0
        pose.lookY = 0.1
        switch variety % 4 {
        case 0:
            // A giggle: eyes squeezed shut, a wiggle side to side.
            pose.eyesOpen = 0
            pose.mouthOpen = 0.9
            pose.tilt = still ? 0 : sin(elapsed * 2 * .pi * 5) * 6 * arc
            pose.squash = 0.08 * arc
        case 1:
            // A spin: a hop that turns all the way around in the air.
            pose.lift += still ? 0 : arc * 9
            pose.mouthOpen = 0.6
            if !still, progress > 0.25, progress < 0.75 { pose.flipped.toggle() }
        case 2:
            // Bashful: eyes closed, a little sway and a puff of hearts.
            pose.eyesOpen = 0
            pose.mouthOpen = 0.3
            pose.headBob += arc * 1.5
            frame.effects.hearts = progress
        default:
            // Surprised, then delighted: a jump with eyes wide open.
            pose.eyesOpen = progress < 0.4 ? 1 : 0
            pose.mouthOpen = progress < 0.4 ? 0.6 : 0.9
            pose.lift += still ? 0 : (progress < 0.5 ? sin(.pi * progress * 2) * 7 : 0)
            pose.earAngle = still ? 0 : sin(elapsed * 2 * .pi * 4) * 10 * arc
        }
        frame.pose = pose
    }

    /// Held: leans into your finger, eyes closed and content, hearts every so often.
    static func petted(for held: Double, on frame: inout PetFrame) {
        let settle = min(1, held / 0.4)
        var pose = frame.pose
        pose.eyesOpen = 1 - settle
        pose.smile = 1
        pose.worry = 0
        pose.mouthOpen = 0.2 * settle
        pose.headBob += 1.8 * settle
        pose.tilt = sin(held * 2.2) * 4 * settle
        pose.tailAngle = sin(held * 2 * .pi / 0.9) * 14
        pose.earAngle = -6 * settle
        pose.lift = 0
        frame.pose = pose
        let beat = held.truncatingRemainder(dividingBy: 1.8)
        if held > 0.6, beat < 1.2 { frame.effects.hearts = beat / 1.2 }
    }

    /// Fresh from a workout: bouncier steps, a faster tail and the odd celebratory hop with a
    /// sparkle, all fading as `level` falls.
    static func pumped(_ level: Double, clock: Double, seed: Int, on frame: inout PetFrame) {
        var pose = frame.pose
        pose.lift *= 1 + 0.6 * level
        pose.tailAngle = sin(clock * 2 * .pi / 0.4) * 12 * level + pose.tailAngle * (1 - level)
        let beat = (clock + Double(seed % 53)).truncatingRemainder(dividingBy: 10)
        if beat < 0.8, pose.tilt == 0, frame.visitor == nil {
            let hop = sin(.pi * beat / 0.8)
            pose.lift += hop * 8 * level
            pose.eyesOpen = 0
            pose.mouthOpen = 0.8
            if frame.effects.prop == nil { frame.effects.prop = .sparkle(beat / 0.8) }
        }
        frame.pose = pose
    }
}
