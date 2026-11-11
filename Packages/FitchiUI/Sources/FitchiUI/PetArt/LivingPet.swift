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

/// A pet that is always a little bit alive. Drawn species animate; the rest show their emoji.
public struct LivingPetView: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let species: Species?
    private let speciesID: String
    private let variant: PetVariant?
    private let excited: Bool
    private let seed: Double

    public init(species: Species?, speciesID: String, variant: PetVariant?, excited: Bool = false, seed: UUID? = nil) {
        self.species = species
        self.speciesID = speciesID
        self.variant = variant
        self.excited = excited
        self.seed = Double(seed?.uuid.0 ?? 0) / 25
    }

    public var body: some View {
        if let species, PetFigure.hasArt(for: speciesID) {
            let palette = PetPalette(species: species, variant: variant)
            if reduceMotion {
                // Reduce Motion: a still pet that only changes expression.
                PetFigure(speciesID: speciesID, palette: palette, pose: excited ? .happy : .standing)
            } else {
                // 20 fps is plenty for a gentle idle; it stops when the wrist is down.
                TimelineView(.animation(minimumInterval: 1.0 / 20, paused: isLuminanceReduced)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    PetFigure(
                        speciesID: speciesID, palette: palette, pose: .idle(at: time, seed: seed, excited: excited))
                }
            }
        } else {
            Text(species?.emoji ?? "🐾")
                .font(.system(size: 52))
                .accessibilityHidden(true)
        }
    }
}
