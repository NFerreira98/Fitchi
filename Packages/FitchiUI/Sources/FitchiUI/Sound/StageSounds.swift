import FitchiCore
import SwiftUI

/// The pet's voice on the stage: a chirp for each boop, a purr when petted, a hello when you
/// come back and a little sound for each care moment. Never while the wrist is down.
struct StageSounds: ViewModifier {
    let voice: PetVoice
    let seed: Int
    let mood: PetMood
    let reaction: StageReaction?
    let boops: Int
    let pats: Int
    let greeting: PetLife.Greeting?
    let quiet: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: boops) { _, count in say(isDozing ? .stir : .boop(count - 1)) }
            .onChange(of: pats) { say(isDozing ? .stir : .purr) }
            .onChange(of: greeting) { _, greeting in
                guard let greeting else { return }
                // In time with the hop, which starts a moment after the pet appears.
                let wait = max(0, greeting.startedAt - Date.now.timeIntervalSinceReferenceDate)
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(wait))
                    say(greeting.isBig ? .bigHello : .hello)
                }
            }
            .onChange(of: reaction?.id) {
                guard let reaction else { return }
                say(reaction.action.map { .care($0) } ?? .happy)
            }
    }

    private var isDozing: Bool {
        mood.isAsleep || PetLife.napAmount(at: Date.now.timeIntervalSinceReferenceDate, seed: seed, mood: mood) > 0.5
    }

    private func say(_ sound: PetSound) {
        guard !quiet else { return }
        PetSounds.shared.play(sound, voice: voice)
    }
}
