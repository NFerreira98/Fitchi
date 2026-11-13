import FitchiCore
import Foundation
import Testing

@testable import FitchiUI

@Suite("Pet voices and sounds")
struct SoundTests {
    let ids = (0..<300).map { _ in UUID() }

    @Test func eachPetHasItsOwnStableVoice() {
        let id = UUID()
        #expect(PetVoice(petID: id, speciesID: "cat") == PetVoice(petID: id, speciesID: "cat"))
        let voices = ids.map { PetVoice(petID: $0, speciesID: "cat") }
        #expect(Set(voices).count > 250, "voices vary from pet to pet")
        #expect(Set(voices.map(\.tone)).count == PetVoice.Tone.allCases.count, "every tone turns up")
        // Pitch, quirks and pace spread right across their ranges.
        let registers = voices.map(\.register)
        #expect(registers.contains { $0 < 0.15 } && registers.contains { $0 > 0.85 })
        #expect(registers.filter { $0 < 0.33 }.count > 60 && registers.filter { $0 > 0.67 }.count > 60)
        #expect(Set(voices.map(\.quirk)).count == PetVoice.Quirk.allCases.count)
        #expect(Set(voices.map(\.name)).count > 25, "lots of different voice names")
        let robots = voices.filter { $0.tone == .robot }.count
        #expect(robots < 30, "robots are rare")
        for voice in voices {
            #expect(PetVoice.range(for: "cat").contains(voice.pitch))
            #expect(!voice.name.isEmpty)
        }
    }

    @Test func everySpeciesHasItsOwnAccent() {
        let species = ["bunny", "cat", "dog", "axolotl", "penguin", "red-panda", "platypus"]
        let accents = Set(species.map(PetVoice.Accent.init(speciesID:)))
        #expect(accents.count == species.count)
        // The same voice with two accents sounds different.
        let cat = PetVoice(
            pitch: 600, tone: .soft, vibrato: 0.01, vibratoRate: 6, pace: 1, register: 0.5,
            accent: .init(speciesID: "cat"))
        var dog = cat
        dog.accent = .init(speciesID: "dog")
        #expect(PetSynth.render(.hello, voice: cat) != PetSynth.render(.hello, voice: dog))
    }

    @Test func smallPetsSqueakHigherThanBigOnes() {
        let bunnies = ids.map { PetVoice(petID: $0, speciesID: "bunny").pitch }
        let dogs = ids.map { PetVoice(petID: $0, speciesID: "dog").pitch }
        #expect(bunnies.reduce(0, +) / Double(ids.count) > dogs.reduce(0, +) / Double(ids.count) * 1.6)
    }

    static let sounds: [PetSound] =
        (0..<4).map { .boop($0) } + [.purr, .stir, .hello, .bigHello, .happy, .cheer]
        + CareAction.allCases.map { .care($0) }

    @Test(arguments: sounds)
    func soundsAreShortSoftAndClean(sound: PetSound) {
        for tone in PetVoice.Tone.allCases {
            for pace in [0.85, 1.15] {
                let voice = PetVoice(pitch: 1_200, tone: tone, vibrato: 0.03, vibratoRate: 8, pace: pace, register: 1)
                let samples = PetSynth.render(sound, voice: voice)
                let seconds = Double(samples.count) / PetSynth.sampleRate
                #expect(seconds > 0.1 && seconds < 1.2, "a quick chirp, not a song")
                #expect(samples.allSatisfy { $0.isFinite && abs($0) <= 0.51 }, "soft, never clipping")
                #expect(samples.contains { abs($0) > 0.05 }, "but audible")
                // Starts and ends at silence, so it never clicks.
                #expect(abs(samples.first ?? 1) < 0.01 && abs(samples.last ?? 1) < 0.01)
            }
        }
    }

    @Test func theSameSoundAlwaysSoundsTheSame() {
        let voice = PetVoice(petID: UUID(), speciesID: "axolotl")
        #expect(PetSynth.render(.hello, voice: voice) == PetSynth.render(.hello, voice: voice))
        #expect(PetSynth.render(.boop(0), voice: voice) != PetSynth.render(.boop(1), voice: voice))
    }
}
