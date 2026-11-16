import FitchiCore
import Foundation

/// Faces, body language and the props that show how the pet feels and what it needs.
extension PetLife {
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
        if mood.isTired || mood.isDown {
            // Ears droop and the head hangs a little.
            pose.earAngle -= mood.isDown ? 9 : 6
            pose.headBob += 1.2
        }
        if mood.isHungry, !mood.isDown {
            // Every 7 s, a look down at its tummy and a lick of the lips.
            let peek = (clock + offset).truncatingRemainder(dividingBy: 7)
            if peek < 1.3 {
                let dip = sin(.pi * peek / 1.3)
                pose.lookY = 0.9 * dip
                pose.lookX = 0
                pose.headBob += 2.2 * dip
                pose.mouthOpen = max(pose.mouthOpen, 0.25 * abs(sin(peek * 12)) * dip)
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
    static func showNeeds(_ mood: PetMood, clock: Double, seed: Int = 0, asleep: Bool, on frame: inout PetFrame) {
        frame.effects.stink = mood.isDirty
        frame.effects.smudges = mood.isDirty
        let poorly = mood.condition == .sick || mood.condition == .packing
        frame.effects.sweat = poorly
        guard !asleep else { return }
        let offset = Double(seed % 97)
        frame.effects.thermometer = poorly
        frame.effects.queasy = poorly
        frame.effects.suitcase = mood.condition == .packing
        if mood.isDirty { frame.effects.fly = clock + offset }
        if mood.condition == .sad { frame.effects.raincloud = clock + offset }
        if mood.isHungry {
            // A tummy rumble every few seconds.
            let beat = (clock + offset).truncatingRemainder(dividingBy: 3.6)
            if beat < 1 { frame.effects.rumble = sin(.pi * beat) }
        }
        // The bubble shows for 4 s of every 9, alternating when it wants both.
        let wants = [mood.isHungry ? CareAction.feed : nil, mood.isBored ? .play : nil].compactMap { $0 }
        guard !wants.isEmpty else { return }
        let cycle = Int((clock / 9).rounded(.down))
        let into = clock - Double(cycle) * 9
        if into < 4 || clock == 0 {
            frame.effects.thought = wants[abs(cycle) % wants.count]
        }
    }
}
