import FitchiCore
import Foundation

/// A little creature that drops by. The pet watches it come in, loop around its head and fly off.
/// Where it is is relative to the pet; the stage picks what it is (butterfly, bird, firefly).
public struct Visitor: Hashable, Sendable {
    public enum Kind: Hashable, Sendable { case butterfly, firefly, bird }

    /// Across from the pet's middle, in pet widths (negative = left). It arrives and leaves off-stage.
    public var offsetX: Double
    /// Above the pet's feet, in pet heights.
    public var height: Double
    public var facingRight: Bool
    /// Seconds, for the wing beat.
    public var clock: Double
    /// Picks one of a few colourings.
    public var variety: Int

    public init(offsetX: Double, height: Double, facingRight: Bool, clock: Double, variety: Int) {
        self.offsetX = offsetX
        self.height = height
        self.facingRight = facingRight
        self.clock = clock
        self.variety = variety
    }
}

extension PetLife {
    /// Hello when you come back: a happy hop facing you, or, after a long time away, a dash to the
    /// front of the scene to celebrate before wandering back.
    public struct Greeting: Hashable, Sendable {
        public var startedAt: TimeInterval
        public var isBig: Bool

        public init(startedAt: TimeInterval, isBig: Bool) {
            self.startedAt = startedAt
            self.isBig = isBig
        }

        public var duration: TimeInterval { isBig ? 4.2 : 1.8 }

        func elapsed(at time: TimeInterval) -> TimeInterval? {
            let elapsed = time - startedAt
            return elapsed >= 0 && elapsed < duration ? elapsed : nil
        }
    }

    /// Roughly one resting slot in eight has a visitor: one every minute or two.
    static let visitChance = 0.13

    /// The visit in progress at `time`, if any: only while the pet is standing about awake and
    /// in good spirits.
    static func visit(at time: TimeInterval, seed: Int, mood: PetMood) -> Visitor? {
        let index = Int((time / slot).rounded(.down))
        guard !mood.isDown, !mood.isAsleep, !strolls(in: index, seed: seed, mood: mood),
            !isNapping(in: index, seed: seed, mood: mood), noise(seed &+ 5, index) < visitChance
        else { return nil }
        let progress = (time - Double(index) * slot) / slot
        let side: Double = noise(seed &+ 6, index) < 0.5 ? -1 : 1
        let now = visitorPath(progress, side: side)
        let soon = visitorPath(min(1, progress + 0.01), side: side)
        return Visitor(
            offsetX: now.x, height: now.height, facingRight: soon.x >= now.x, clock: time,
            variety: Int(noise(seed &+ 7, index) * 3))
    }

    /// Flies in from one side, loops one and a half times around the pet's head, leaves the other way.
    static func visitorPath(_ progress: Double, side: Double) -> (x: Double, height: Double) {
        let loop = 0.45
        switch progress {
        case ..<0.3:
            let eased = SceneLight.smooth(progress / 0.3)
            return (side * (2.6 + (loop - 2.6) * eased), 1.3 - 0.25 * eased + 0.05 * sin(progress * 60))
        case ..<0.7:
            let angle = (progress - 0.3) / 0.4 * 3 * .pi
            return (side * loop * cos(angle), 1.05 + 0.16 * sin(angle))
        default:
            let eased = SceneLight.smooth((progress - 0.7) / 0.3)
            return (-side * (loop + (2.8 - loop) * eased), 1.05 + 0.5 * eased + 0.05 * sin(progress * 60))
        }
    }

    /// Turns to watch the visitor, and gets excited when it loops right overhead.
    static func watch(_ visitor: Visitor, on frame: inout PetFrame) {
        frame.visitor = visitor
        var pose = frame.pose
        pose.flipped = visitor.offsetX > 0
        pose.lookX = -min(1, abs(visitor.offsetX) * 1.5 + 0.2)
        pose.lookY = -0.8
        if abs(visitor.offsetX) < 0.3, visitor.height < 1.3 {
            let close = 1 - abs(visitor.offsetX) / 0.3
            pose.lift += close * 3
            pose.mouthOpen = max(pose.mouthOpen, close * 0.7)
            pose.tailAngle = sin(visitor.clock * 2 * .pi / 0.35) * 12
        }
        frame.pose = pose
    }

    /// A small hello on the spot, facing you: two hops with a grin and a wagging tail.
    static func greet(elapsed: TimeInterval, on pose: inout PetPose) {
        let hops = elapsed < 1.2 ? abs(sin(elapsed * .pi / 0.6)) : 0
        pose.lookX = 0
        pose.lookY = 0.2
        pose.lift += hops * 6
        pose.eyesOpen = hops > 0.2 ? 0 : pose.eyesOpen
        pose.mouthOpen = 0.8
        pose.smile = 1
        pose.worry = 0
        pose.tailAngle = sin(elapsed * 2 * .pi / 0.3) * 14
        pose.earAngle = sin(elapsed * 2 * .pi / 0.4) * 8
    }

    /// The big hello's frame at `time`, if one is playing (a napping pet sleeps through it).
    static func bigGreeting(
        _ greeting: Greeting, at time: TimeInterval, seed: Int, mood: PetMood, clock: Double
    ) -> PetFrame? {
        guard greeting.isBig, let elapsed = greeting.elapsed(at: time),
            napAmount(at: greeting.startedAt, seed: seed, mood: mood) == 0
        else { return nil }
        var frame = bigGreeting(greeting, elapsed: elapsed, seed: seed, mood: mood, clock: clock)
        showNeeds(mood, clock: clock, asleep: false, on: &frame)
        return frame
    }

    /// The big hello: run to the front, celebrate, then stroll back to where it would have been.
    static func bigGreeting(
        _ greeting: Greeting, elapsed: TimeInterval, seed: Int, mood: PetMood, clock: Double
    ) -> PetFrame {
        var frame = PetFrame()
        frame.effects.clock = clock
        frame.pose = PetPose.idle(at: clock, seed: Double(seed % 1000) / 25)
        let start = position(at: greeting.startedAt, seed: seed, mood: mood)
        let end = position(at: greeting.startedAt + greeting.duration, seed: seed, mood: mood)
        let front = (x: 0.0, depth: 0.95)
        let run = 1.3
        let back = greeting.duration - 1.3
        if elapsed < run {
            let eased = SceneLight.smooth(elapsed / run)
            frame.x = start.x + (front.x - start.x) * eased
            frame.depth = start.depth + (front.depth - start.depth) * eased
            frame.pose.flipped = front.x > start.x
            walk(&frame.pose, stride: elapsed * 1.6)
            frame.pose.mouthOpen = 0.6
        } else if elapsed < back {
            frame.x = front.x
            frame.depth = front.depth
            greet(elapsed: elapsed - run, on: &frame.pose)
            frame.effects.hearts = min(1, (elapsed - run) / 1.4)
        } else {
            let eased = SceneLight.smooth((elapsed - back) / (greeting.duration - back))
            frame.x = front.x + (end.x - front.x) * eased
            frame.depth = front.depth + (end.depth - front.depth) * eased
            frame.pose.flipped = end.x > front.x
            if abs(end.x - front.x) + abs(end.depth - front.depth) > 0.05 {
                walk(&frame.pose, stride: elapsed - back)
            }
        }
        return frame
    }
}
