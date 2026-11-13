import Foundation

extension PetVoice {
    /// How a species speaks, whatever its pitch and tone: the shape of each chirp, how clipped
    /// or drawn out it is, whether it trills, and how breathy.
    public struct Accent: Hashable, Sendable {
        public var contour: VoiceContour
        /// Chirp length: below 1 clipped and quick, above 1 drawn out.
        public var staccato: Double
        /// Each short chirp broken into this many quick pieces (a gurgle or a twitter).
        public var trill: Int
        /// A breathy puff at the start of each chirp, 0 … 1.
        public var breath: Double
        /// The tone this species usually has.
        public var home: Tone

        public static let plain = Accent(contour: .flat, staccato: 1, trill: 1, breath: 0, home: .soft)

        public init(contour: VoiceContour, staccato: Double, trill: Int, breath: Double, home: Tone) {
            self.contour = contour
            self.staccato = staccato
            self.trill = trill
            self.breath = breath
            self.home = home
        }

        public init(speciesID: String) {
            switch speciesID {
            case "bunny": self.init(contour: .squeak, staccato: 0.65, trill: 1, breath: 0.05, home: .pure)
            case "cat": self.init(contour: .mew, staccato: 1.3, trill: 1, breath: 0.08, home: .reedy)
            case "dog": self.init(contour: .woof, staccato: 0.8, trill: 1, breath: 0.4, home: .soft)
            case "axolotl": self.init(contour: .flat, staccato: 1, trill: 3, breath: 0, home: .bubbly)
            case "penguin": self.init(contour: .honk, staccato: 0.9, trill: 1, breath: 0.2, home: .reedy)
            case "red-panda": self.init(contour: .squeak, staccato: 0.8, trill: 2, breath: 0.05, home: .pure)
            case "platypus": self.init(contour: .mew, staccato: 1, trill: 2, breath: 0.2, home: .bubbly)
            default: self = .plain
            }
        }
    }

    /// A phrase as this voice says it: the accent's trills and chirp lengths, then the quirk.
    func shape(_ notes: [PetSound.Note]) -> [PetSound.Note] {
        var shaped = notes.flatMap(trilled).map { note in
            guard note.flutter == 0 else { return note }
            var clipped = note
            clipped.length = max(0.03, note.length * accent.staccato)
            return clipped
        }
        let end = shaped.map { $0.start + $0.length }.max() ?? 0
        switch quirk {
        case .none, .gravelly: break
        case .hiccup:
            shaped = shaped.map { note in
                var later = note
                later.start += 0.06
                return later
            }
            shaped.insert(PetSound.Note(start: 0, length: 0.035, from: 1.5, toward: 1.6, volume: 0.6), at: 0)
        case .squeaky:
            shaped.append(PetSound.Note(start: end + 0.02, length: 0.05, from: 2.2, toward: 2.6, volume: 0.4))
        case .echo:
            if var last = shaped.last {
                last.start = end + 0.07
                last.volume *= 0.4
                shaped.append(last)
            }
        }
        return shaped
    }

    /// A short chirp broken into a quick run of pieces, alternating a little up and down.
    private func trilled(_ note: PetSound.Note) -> [PetSound.Note] {
        guard accent.trill > 1, note.flutter == 0, note.length < 0.45 else { return [note] }
        let count = accent.trill
        let piece = note.length / Double(count)
        return (0..<count).map { index in
            let from = note.from + (note.toward - note.from) * Double(index) / Double(count)
            let toward = note.from + (note.toward - note.from) * Double(index + 1) / Double(count)
            let lift = index.isMultiple(of: 2) ? 1.0 : 1.08
            return PetSound.Note(
                start: note.start + Double(index) * piece, length: piece * 0.85, from: from * lift,
                toward: toward * lift, volume: note.volume)
        }
    }
}

/// The pitch shape of each chirp.
public enum VoiceContour: Hashable, Sendable {
    case flat
    /// Rises and falls, like a mew.
    case mew
    /// Pops up, then drops away at the end, like a woof.
    case woof
    /// Starts with a high flick, like a squeak.
    case squeak
    /// Dips in the middle, like a honk.
    case honk
}
