import AVFoundation
import SwiftUI

/// Plays pet sounds. Quiet when switched off in settings, and it mixes politely with whatever
/// else is playing: as "ambient" audio it follows the silent switch on iPhone.
@MainActor
public final class PetSounds {
    public static let shared = PetSounds()
    /// `@AppStorage` key for the on/off switch (on by default).
    public static let enabledKey = "fitchi.petSounds"

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat?
    private var buffers: [Key: AVAudioPCMBuffer] = [:]
    private var lastPlayed = Date.distantPast

    private struct Key: Hashable {
        var sound: PetSound
        var voice: PetVoice
    }

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: PetSynth.sampleRate, channels: 1)
        engine.attach(player)
        if let format { engine.connect(player, to: engine.mainMixerNode, format: format) }
    }

    public static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// Says `sound` in `voice`, cutting off whatever it was saying before.
    public func play(_ sound: PetSound, voice: PetVoice) {
        guard Self.isEnabled, let buffer = buffer(for: Key(sound: sound, voice: voice)) else { return }
        guard start() else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
        lastPlayed = .now
        // Let the audio hardware rest once things have been quiet for a while.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, Date.now.timeIntervalSince(self.lastPlayed) >= 3.9 else { return }
            self.engine.pause()
        }
    }

    private func start() -> Bool {
        guard !engine.isRunning else { return true }
        #if !os(macOS)
            try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    private func buffer(for key: Key) -> AVAudioPCMBuffer? {
        if let cached = buffers[key] { return cached }
        let samples = PetSynth.render(key.sound, voice: key.voice)
        guard let format, !samples.isEmpty,
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
            let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress { channel.update(from: base, count: samples.count) }
        }
        if buffers.count > 40 { buffers.removeAll() }
        buffers[key] = buffer
        return buffer
    }
}

/// The pet's voice on its page: what it sounds like, a button to hear it and the sound switch.
public struct PetVoiceRow: View {
    @AppStorage(PetSounds.enabledKey) private var soundsOn = true
    private let voice: PetVoice
    private let petName: String
    private let compact: Bool

    public init(voice: PetVoice, petName: String, compact: Bool = false) {
        self.voice = voice
        self.petName = petName
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: FitchiTheme.Spacing.s) {
            Button {
                PetSounds.shared.play(.hello, voice: voice)
            } label: {
                Label(voice.name, systemImage: soundsOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            .disabled(!soundsOn)
            .accessibilityLabel("Hear \(petName)'s voice: \(voice.name)")
            Spacer(minLength: 0)
            Toggle("Sounds", isOn: $soundsOn)
                .labelsHidden()
                .accessibilityLabel("Pet sounds")
        }
        .font(FitchiTheme.Fonts.text(compact ? .footnote : .subheadline, weight: .semibold))
    }
}
