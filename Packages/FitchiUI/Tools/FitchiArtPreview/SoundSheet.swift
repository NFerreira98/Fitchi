import FitchiUI
import Foundation

/// Every sound in a few sample voices, as WAV files.
enum SoundSheet {
    static func write(to directory: String) throws {
        let folder = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let sounds: [(String, PetSound)] =
            (0..<4).map { ("boop\($0)", PetSound.boop($0)) } + [
                ("purr", .purr), ("stir", .stir), ("hello", .hello), ("big-hello", .bigHello), ("feed", .care(.feed)),
                ("play", .care(.play)), ("wash", .care(.wash)), ("rest", .care(.rest)), ("happy", .happy),
            ]
        let species = ["bunny", "red-panda", "axolotl", "cat", "platypus", "penguin", "dog"]
        for (index, speciesID) in species.enumerated() {
            // Four pets of each species, as they'd really be born.
            for pet in 1...4 {
                let id = UUID(
                    uuidString: String(format: "%08X-1234-4321-8765-%012X", index * 7_919 + pet, pet * 104_729))
                let voice = PetVoice(petID: id, speciesID: speciesID)
                var all: [Float] = []
                for (_, sound) in sounds {
                    all += PetSynth.render(sound, voice: voice) + [Float](repeating: 0, count: 6_000)
                }
                let file = "\(index + 1)-\(speciesID)-\(pet) \(voice.name).wav"
                try wav(all).write(to: folder.appendingPathComponent(file))
            }
        }
        print("Wrote sounds to \(directory)")
    }

    /// 16-bit mono PCM.
    static func wav(_ samples: [Float]) -> Data {
        var data = Data()
        func append<Value: FixedWidthInteger>(_ value: Value) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        let rate = UInt32(PetSynth.sampleRate)
        data.append(contentsOf: Array("RIFF".utf8))
        append(UInt32(36 + samples.count * 2))
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(UInt16(1))
        append(rate)
        append(rate * 2)
        append(UInt16(2))
        append(UInt16(16))
        data.append(contentsOf: Array("data".utf8))
        append(UInt32(samples.count * 2))
        for sample in samples { append(Int16(max(-1, min(1, sample)) * 32_000)) }
        return data
    }
}
