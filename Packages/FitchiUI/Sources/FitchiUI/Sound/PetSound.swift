import FitchiCore
import Foundation

/// Something a pet says. Each is a short phrase of chirps, sung in the pet's own voice.
public enum PetSound: Hashable, Sendable {
    /// A boop; each one in a row gets a different reaction (giggle, whee, aww, eep).
    case boop(Int)
    /// Being petted: a low, fluttering purr.
    case purr
    /// A sleepy "mm?" when a sleeping pet is touched.
    case stir
    case hello
    case bigHello
    case care(CareAction)
    /// A happy little tune (a gift, a celebration).
    case happy
    /// A milestone fanfare: up the scale and a long, wobbly top note.
    case cheer

    /// One chirp: a glide from one pitch to another (as multiples of the voice's pitch).
    struct Note: Sendable {
        var start: Double
        var length: Double
        var from: Double
        var toward: Double
        var volume: Double = 1
        /// A fast tremble in loudness, for purring and bubbles.
        var flutter: Double = 0
    }

    /// The phrase, before the voice's pace is applied.
    var notes: [Note] {
        switch self {
        case .boop(let variety): Self.boop(variety)
        case .purr:
            [Note(start: 0, length: 0.75, from: 0.5, toward: 0.47, volume: 0.6, flutter: 24)]
        case .stir:
            [
                Note(start: 0, length: 0.28, from: 0.8, toward: 0.72, volume: 0.35),
                Note(start: 0.3, length: 0.2, from: 0.74, toward: 0.86, volume: 0.3),
            ]
        case .hello:
            [
                Note(start: 0, length: 0.12, from: 1, toward: 1.12),
                Note(start: 0.15, length: 0.2, from: 1.3, toward: 1.55),
            ]
        case .bigHello:
            [1.0, 1.26, 1.5, 2.0].enumerated().map { index, step in
                Note(start: Double(index) * 0.09, length: 0.08, from: step, toward: step * 1.04)
            } + [Note(start: 0.38, length: 0.32, from: 1.6, toward: 2.1)]
        case .care(let action): Self.care(action)
        case .cheer:
            [1.0, 1.26, 1.5].enumerated().map { index, step in
                Note(start: Double(index) * 0.09, length: 0.07, from: step, toward: step)
            } + [
                Note(start: 0.28, length: 0.3, from: 2, toward: 2.1),
                Note(start: 0.62, length: 0.07, from: 1.5, toward: 1.6),
                Note(start: 0.7, length: 0.22, from: 2, toward: 2.2),
            ]
        case .happy:
            [1.0, 1.26, 1.5].enumerated().map { index, step in
                Note(start: Double(index) * 0.11, length: index == 2 ? 0.22 : 0.1, from: step, toward: step)
            }
        }
    }

    private static func boop(_ variety: Int) -> [Note] {
        switch variety % 4 {
        case 0:  // Giggle.
            (0..<3).map {
                Note(
                    start: Double($0) * 0.09, length: 0.07, from: 1.2 + 0.1 * Double($0),
                    toward: 1.5 + 0.12 * Double($0))
            }
        case 1:  // Wheee!
            [Note(start: 0, length: 0.38, from: 0.9, toward: 1.8)]
        case 2:  // Aww.
            [Note(start: 0, length: 0.32, from: 1.3, toward: 1, volume: 0.6)]
        default:  // Eep!
            [Note(start: 0, length: 0.07, from: 1, toward: 2.1), Note(start: 0.07, length: 0.06, from: 2.1, toward: 2)]
        }
    }

    private static func care(_ action: CareAction) -> [Note] {
        switch action {
        case .feed:  // Nom, nom, nom, mmm.
            (0..<3).map { Note(start: Double($0) * 0.2, length: 0.06, from: 0.82, toward: 0.74, volume: 0.7) }
                + [Note(start: 0.68, length: 0.26, from: 1.05, toward: 1.2)]
        case .play:  // Wheee, hee!
            [
                Note(start: 0, length: 0.3, from: 1, toward: 1.7),
                Note(start: 0.36, length: 0.12, from: 1.5, toward: 1.6),
            ]
        case .wash:  // Bubbles popping, then a shake.
            [2.4, 2.9, 2.2, 3.1, 2.6].enumerated().map { index, step in
                Note(start: Double(index) * 0.07, length: 0.035, from: step, toward: step * 1.1, volume: 0.45)
            } + [Note(start: 0.45, length: 0.3, from: 1.1, toward: 1.2, volume: 0.6, flutter: 14)]
        case .rest:  // A long yawn.
            [Note(start: 0, length: 0.65, from: 1.2, toward: 0.6, volume: 0.55)]
        }
    }
}
