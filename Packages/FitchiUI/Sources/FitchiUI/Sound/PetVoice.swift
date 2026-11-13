import Foundation

/// Every pet has its own little voice. The species gives it an accent (cats mew, dogs woof,
/// bunnies squeak, axolotls gurgle); the pet rolls the rest: pitch within its species' range, a
/// tone colour, how bright it is, a wobble, a pace and sometimes a quirk. Like the pet's
/// behaviour it comes from the pet's id, so it never needs saving, survives backups and sounds
/// the same on the watch and the phone.
public struct PetVoice: Hashable, Sendable {
    /// The tone colour of the voice.
    public enum Tone: String, CaseIterable, Sendable {
        /// A clean whistle.
        case pure
        /// Rounded and warm.
        case soft
        /// Brighter, with a reedy buzz.
        case reedy
        /// Burbling, as if through water.
        case bubbly
        /// Rare: a little chiptune robot.
        case robot
    }

    /// A habit of speech some pets have.
    public enum Quirk: String, CaseIterable, Sendable {
        case none
        /// A tiny hic before it speaks.
        case hiccup
        /// A high squeak to finish.
        case squeaky
        /// Says the last bit again, softer.
        case echo
        /// A breathy rasp.
        case gravelly
    }

    /// Hz of the voice's resting note.
    public var pitch: Double
    public var tone: Tone
    /// How much longer notes wobble (0 none … 0.04 lots), and how fast.
    public var vibrato: Double
    public var vibratoRate: Double
    /// Speaks faster (> 1) or slower (< 1).
    public var pace: Double
    /// 0 … 1, where the pitch sits within the species' range (low … high).
    public var register: Double
    /// 0 … 1, how much shimmer of overtones sits on top of the tone.
    public var brightness: Double
    public var quirk: Quirk
    /// How the species speaks.
    public var accent: Accent

    public init(
        pitch: Double, tone: Tone, vibrato: Double, vibratoRate: Double, pace: Double, register: Double,
        brightness: Double = 0.4, quirk: Quirk = .none, accent: Accent = .plain
    ) {
        self.pitch = pitch
        self.tone = tone
        self.vibrato = vibrato
        self.vibratoRate = vibratoRate
        self.pace = pace
        self.register = register
        self.brightness = brightness
        self.quirk = quirk
        self.accent = accent
    }

    /// The voice a pet was born with.
    public init(petID: UUID?, speciesID: String) {
        let seed = Self.seed(petID)
        func roll(_ index: Int) -> Double { PetLife.noise(seed, index) }
        let range = Self.range(for: speciesID)
        let accent = Accent(speciesID: speciesID)
        let register = roll(1)
        // A rare robot (about 1 in 25); otherwise often the species' own tone, or any other.
        let toneRoll = roll(2)
        let tone: Tone =
            toneRoll < 0.04
            ? .robot
            : toneRoll < 0.5
                ? accent.home
                : [Tone.pure, .soft, .reedy, .bubbly][Int(roll(3) * 4) % 4]
        let quirkRoll = roll(4)
        let quirk: Quirk =
            quirkRoll < 0.55
            ? .none : quirkRoll < 0.67 ? .hiccup : quirkRoll < 0.79 ? .squeaky : quirkRoll < 0.9 ? .echo : .gravelly
        self.init(
            pitch: range.lowerBound * pow(range.upperBound / range.lowerBound, register), tone: tone,
            vibrato: tone == .robot ? 0 : 0.004 + 0.034 * roll(5), vibratoRate: 4 + 5 * roll(6),
            pace: 0.82 + 0.36 * roll(7), register: register, brightness: roll(8), quirk: quirk, accent: accent)
    }

    /// The whole id mixed into one number (parts of a random UUID are fixed, so no single byte will do).
    static func seed(_ id: UUID?) -> Int {
        guard let id else { return 0 }
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        withUnsafeBytes(of: id.uuid) { bytes in
            for byte in bytes { hash = (hash ^ UInt64(byte)) &* 0x100_0000_01B3 }
        }
        return Int(truncatingIfNeeded: hash)
    }

    /// Small pets squeak higher; bigger ones are lower.
    static func range(for speciesID: String) -> ClosedRange<Double> {
        switch speciesID {
        case "bunny": 900...1400
        case "red-panda": 700...1050
        case "axolotl": 620...950
        case "cat": 520...820
        case "platypus": 420...660
        case "penguin": 380...600
        case "dog": 300...520
        default: 520...820
        }
    }

    /// Pitch ranges by species, for previews.
    public enum Range {
        public static func middle(of speciesID: String) -> Double {
            let range = PetVoice.range(for: speciesID)
            return (range.lowerBound * range.upperBound).squareRoot()
        }
    }

    /// "Bubbly warbling soprano with a hiccup", for the pet's page.
    public var name: String {
        let part = register < 0.33 ? "alto" : register < 0.67 ? "tenor" : "soprano"
        let colour =
            switch tone {
            case .pure: "Whistly"
            case .soft: "Mellow"
            case .reedy: "Buzzy"
            case .bubbly: "Bubbly"
            case .robot: "Robo"
            }
        let habit =
            switch quirk {
            case .none: ""
            case .hiccup: " with a hiccup"
            case .squeaky: " with a squeak"
            case .echo: " with an echo"
            case .gravelly: " with a rasp"
            }
        return (vibrato > 0.028 ? "\(colour) warbling \(part)" : "\(colour) \(part)") + habit
    }
}
