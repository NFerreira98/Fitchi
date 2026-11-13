import FitchiCore
import Foundation

extension PetLife {
    /// Celebrating a milestone you just reached: three big jumps with a twirl and confetti.
    public struct Cheer: Hashable, Sendable {
        public var startedAt: TimeInterval

        public init(startedAt: TimeInterval) {
            self.startedAt = startedAt
        }

        public static let duration: TimeInterval = 3

        func elapsed(at time: TimeInterval) -> TimeInterval? {
            let elapsed = time - startedAt
            return elapsed >= 0 && elapsed < Self.duration ? elapsed : nil
        }
    }

    static func cheer(elapsed: TimeInterval, still: Bool, on frame: inout PetFrame) {
        var pose = frame.pose
        let jump = 0.75
        let hop = elapsed < jump * 3 ? abs(sin(.pi * elapsed / jump)) : 0
        pose.lift += still ? 0 : hop * 13
        pose.squash = hop < 0.15 && elapsed < jump * 3 ? 0.12 : -0.08 * hop
        // A twirl on the middle jump.
        if !still, elapsed > jump, elapsed < jump * 2, Int((elapsed - jump) / (jump / 4)).isMultiple(of: 2) {
            pose.flipped.toggle()
        }
        pose.eyesOpen = 0
        pose.mouthOpen = 1
        pose.smile = 1
        pose.worry = 0
        pose.lookX = 0
        pose.tailAngle = sin(elapsed * 2 * .pi / 0.22) * 18
        pose.earAngle = sin(elapsed * 2 * .pi / 0.3) * 12
        frame.pose = pose
        frame.effects.confetti = min(1, elapsed / Cheer.duration)
    }

    /// How the pet copes with the weather: shaking off rain and hopping in puddles, ears blown
    /// back in the wind, trying to catch snowflakes.
    static func weatherReaction(
        _ weather: Weather, at time: TimeInterval, seed: Int, mood: PetMood, on frame: inout PetFrame
    ) {
        let offset = Double(seed % 89)
        var pose = frame.pose
        switch weather.kind {
        case .rain:
            pose.eyesOpen = min(pose.eyesOpen, 1 - 0.3 * weather.amount)
            // A shake to get the water off every 9 s.
            let shake = (time + offset).truncatingRemainder(dividingBy: 9)
            if shake < 0.9 {
                let wiggle = sin(shake * 2 * .pi * 6)
                pose.tilt += wiggle * 6 * sin(.pi * shake / 0.9)
                pose.earAngle = wiggle * 14
                pose.eyesOpen = 0
            }
            if let splash = puddleHop(at: time, seed: seed, mood: mood) {
                pose.lift += abs(sin(.pi * splash * 2)) * 7
                pose.mouthOpen = 0.8
                frame.effects.splash = (splash * 2).truncatingRemainder(dividingBy: 1)
            }
        case .wind:
            // Ears (and gills) streaming back, leaning into it.
            let gust = weather.amount * (0.7 + 0.3 * sin(time * 1.3 + offset))
            pose.earAngle += -12 * gust + sin(time * 11) * 4 * gust
            pose.tilt += (pose.flipped ? -1 : 1) * 4 * gust
            pose.eyesOpen = min(pose.eyesOpen, 1 - 0.35 * gust)
        case .snow:
            // Every 12 s, looks up and tries to catch a flake.
            let catchAt = (time + offset).truncatingRemainder(dividingBy: 12)
            if catchAt < 1.6, !mood.isDown {
                let open = sin(.pi * catchAt / 1.6)
                pose.lookX = 0
                pose.lookY = -1
                pose.mouthOpen = max(pose.mouthOpen, open * 0.7)
                pose.headBob -= 2 * open
            }
        case .clear, .cloudy:
            break
        }
        frame.pose = pose
    }

    /// 0…1 through a puddle-jumping spell (two splashes), if one is on: about one resting slot
    /// in four on a rainy day, for a happy pet.
    static func puddleHop(at time: TimeInterval, seed: Int, mood: PetMood) -> Double? {
        let index = Int((time / slot).rounded(.down))
        guard !mood.isDown, !mood.isTired, !strolls(in: index, seed: seed, mood: mood),
            !isNapping(in: index, seed: seed, mood: mood), noise(seed &+ 11, index) < 0.25
        else { return nil }
        let into = time - Double(index) * slot - 2
        return into >= 0 && into < 1.4 ? into / 1.4 : nil
    }
}
