import Foundation

/// Renders pet sounds as audio samples: plain arithmetic, so it's the same everywhere and tests
/// can check it.
public enum PetSynth {
    public static let sampleRate = 22_050.0

    /// Mono samples in −1…1.
    public static func render(_ sound: PetSound, voice: PetVoice) -> [Float] {
        let notes = voice.shape(sound.notes)
        let pace = 1 / voice.pace
        let end = (notes.map { $0.start + $0.length }.max() ?? 0) * pace + 0.05
        var samples = [Float](repeating: 0, count: Int(end * sampleRate))
        for note in notes {
            add(note, voice: voice, pace: pace, into: &samples)
        }
        // Keep it soft; nothing should ever clip.
        let peak = samples.map(abs).max() ?? 0
        let gain = peak > 0 ? Float(0.5) / max(peak, 0.5) : 0
        return samples.map { $0 * gain }
    }

    private static func add(_ note: PetSound.Note, voice: PetVoice, pace: Double, into samples: inout [Float]) {
        let first = Int(note.start * pace * sampleRate)
        let count = Int(note.length * pace * sampleRate)
        var phase = 0.0
        for offset in 0..<count where first + offset < samples.count {
            let time = Double(offset) / sampleRate
            let progress = Double(offset) / Double(max(count, 1))
            // Glide with an ease, shaped by the accent, and a wobble that grows on longer notes.
            let eased = progress * progress * (3 - 2 * progress)
            let wobble = 1 + voice.vibrato * min(1, time / 0.15) * sin(2 * .pi * voice.vibratoRate * time)
            let glide = note.from + (note.toward - note.from) * eased
            let frequency = voice.pitch * glide * wobble * contour(voice.accent.contour, progress, time)
            phase += frequency / sampleRate
            phase -= phase.rounded(.down)
            // A quick fade in and a gentle fade out, so chirps never click.
            let envelope = min(1, time / 0.008) * min(1, (Double(count - offset) / sampleRate) / 0.03)
            let flutter = note.flutter > 0 ? 0.65 + 0.35 * sin(2 * .pi * note.flutter * time) : 1
            var value = wave(voice.tone, phase: phase, time: time, brightness: voice.brightness)
            // Breath at the start of each chirp (a gruff dog), or a rasp all through.
            let breath = voice.accent.breath * exp(-time / 0.03) + (voice.quirk == .gravelly ? 0.18 : 0)
            value = value * (1 - breath * 0.5) + noise(first + offset) * breath
            samples[first + offset] += Float(value * envelope * flutter * note.volume)
        }
    }

    /// Pitch multiplier for the accent's shape at a point in a chirp.
    static func contour(_ contour: VoiceContour, _ progress: Double, _ time: Double) -> Double {
        switch contour {
        case .flat: 1
        case .mew: 0.9 + 0.22 * sin(.pi * min(1, progress * 1.2))
        case .woof: (1 - 0.15 * exp(-time / 0.015)) * (1 - 0.28 * max(0, (progress - 0.55) / 0.45))
        case .squeak: 1 + 0.35 * exp(-time / 0.02)
        case .honk: 1 - 0.12 * sin(.pi * progress)
        }
    }

    static func wave(_ tone: PetVoice.Tone, phase: Double, time: Double, brightness: Double) -> Double {
        let angle = 2 * .pi * phase
        let shimmer = brightness * 0.3 * sin(2 * angle) + brightness * 0.12 * sin(3 * angle)
        switch tone {
        case .pure: return sin(angle) + shimmer * 0.5
        case .soft: return (sin(angle) + 0.25 * sin(2 * angle) + 0.08 * sin(3 * angle)) / 1.2 + shimmer * 0.5
        case .reedy:
            return (sin(angle) + 0.5 * sin(2 * angle) + 0.33 * sin(3 * angle) + 0.2 * sin(4 * angle)) / 1.6 + shimmer
        case .bubbly: return sin(angle + 0.7 * sin(angle)) * (0.7 + 0.3 * sin(2 * .pi * 30 * time)) + shimmer * 0.4
        case .robot: return tanh(3 * sin(angle)) * 0.8
        }
    }

    /// Repeatable hiss, −1…1, for breath and rasp.
    static func noise(_ index: Int) -> Double {
        var value = UInt32(truncatingIfNeeded: index) &* 747_796_405 &+ 2_891_336_453
        value = ((value >> ((value >> 28) + 4)) ^ value) &* 277_803_737
        value = (value >> 22) ^ value
        return Double(value) / Double(UInt32.max) * 2 - 1
    }
}
