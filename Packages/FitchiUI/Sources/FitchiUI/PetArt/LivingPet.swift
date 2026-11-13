import FitchiCore
import SwiftUI

public extension PetPose {
    /// Eyes squeezed shut in a grin.
    static let happy: PetPose = {
        var pose = PetPose()
        pose.eyesOpen = 0
        pose.mouthOpen = 0.8
        return pose
    }()

    /// A calm idle loop: breathing, blinking, a lazy tail and the odd glance around.
    /// `seed` offsets the rhythm so two pets never breathe in sync.
    static func idle(at time: TimeInterval, seed: Double = 0, excited: Bool = false) -> PetPose {
        let clock = time + seed * 7.3
        let breath = sin(clock * 2 * .pi / 3.2)
        var pose = PetPose()
        pose.headBob = breath * 0.9
        pose.squash = breath * 0.02
        pose.earAngle = sin(clock * 2 * .pi / 3.2 + 1) * 3
        pose.tailAngle = excited ? sin(clock * 2 * .pi / 0.35) * 14 : sin(clock * 2 * .pi / 2.4) * 6
        pose.lookX = max(-1, min(1, sin(clock * 0.45) * 2.2)) * 0.8
        pose.lookY = sin(clock * 0.31) > 0.85 ? -0.6 : 0
        // Blink for ~0.16 s every 4.3 s.
        let blink = clock.truncatingRemainder(dividingBy: 4.3)
        pose.eyesOpen = blink < 0.16 ? abs(blink - 0.08) / 0.08 : 1
        if excited {
            pose.eyesOpen = 0
            pose.mouthOpen = 0.8
            pose.lift = abs(sin(clock * 2 * .pi / 0.5)) * 4
        }
        return pose
    }
}

/// A pet that is always a little bit alive: breathing, blinking and glancing about, and every
/// dozen seconds or so doing its personality's little habit (or a happy hop). Drawn species
/// animate; the rest show their emoji.
public struct LivingPetView: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let species: Species?
    private let speciesID: String
    private let variant: PetVariant?
    private let excited: Bool
    private let seed: Double
    private let accessories: [AccessorySlot: String]
    private let personality: Personality?
    private let framesPerSecond: Double

    /// - Parameters:
    ///   - personality: shows its habit now and then; nil for a plain hop.
    ///   - framesPerSecond: lower it for grids of many pets.
    public init(
        species: Species?, speciesID: String, variant: PetVariant?, excited: Bool = false, seed: UUID? = nil,
        accessories: [AccessorySlot: String] = [:], personality: Personality? = nil, framesPerSecond: Double = 20
    ) {
        self.init(
            species: species, speciesID: speciesID, variant: variant, excited: excited,
            seedValue: Double(seed?.uuid.0 ?? 0) / 25 + Double(seed?.uuid.1 ?? 0) / 300, accessories: accessories,
            personality: personality, framesPerSecond: framesPerSecond)
    }

    /// With a seed number rather than an id (collection entries, which aren't pets).
    public init(
        species: Species?, speciesID: String, variant: PetVariant?, excited: Bool = false, seedValue: Double,
        accessories: [AccessorySlot: String] = [:], personality: Personality? = nil, framesPerSecond: Double = 20
    ) {
        self.species = species
        self.speciesID = speciesID
        self.variant = variant
        self.excited = excited
        self.seed = seedValue
        self.accessories = accessories
        self.personality = personality
        self.framesPerSecond = framesPerSecond
    }

    public var body: some View {
        if let species, PetFigure.hasArt(for: speciesID) {
            let palette = PetPalette(species: species, variant: variant)
            if reduceMotion {
                // Reduce Motion: a still pet that only changes expression.
                PetFigure(
                    speciesID: speciesID, palette: palette, pose: excited ? .happy : .standing,
                    accessories: accessories)
            } else {
                // A gentle idle needs few frames; it stops when the wrist is down.
                let schedule = AnimationTimelineSchedule(
                    minimumInterval: 1 / framesPerSecond, paused: isLuminanceReduced)
                TimelineView(schedule) { timeline in
                    let frame = Self.frame(
                        at: timeline.date.timeIntervalSinceReferenceDate, seed: seed, excited: excited,
                        personality: personality)
                    PetFigure(
                        speciesID: speciesID, palette: palette, pose: frame.pose, effects: frame.effects,
                        accessories: accessories)
                }
            }
        } else {
            Text(species?.emoji ?? "🐾")
                .font(.system(size: 52))
                .accessibilityHidden(true)
        }
    }

    /// The idle at `time`, with a habit (or a hop) once every 11–15 s, offset by `seed`.
    static func frame(at time: TimeInterval, seed: Double, excited: Bool, personality: Personality?) -> PetFrame {
        var frame = PetFrame()
        frame.effects.clock = time
        frame.pose = .idle(at: time, seed: seed, excited: excited)
        guard !excited else { return frame }
        let cycle = 11 + seed.truncatingRemainder(dividingBy: 4)
        let into = (time + seed * 3.1).truncatingRemainder(dividingBy: cycle)
        guard into < PetLife.habitLength else { return frame }
        if let personality {
            PetLife.perform(personality, elapsed: into, on: &frame)
        } else if into < 0.9 {
            frame.pose.lift += sin(.pi * into / 0.45).magnitude * 5
            frame.pose.eyesOpen = 0
            frame.pose.mouthOpen = 0.7
        }
        return frame
    }
}
