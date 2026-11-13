import FitchiCore
import SwiftUI

/// What to show and feel after a care tap or a collected gift: the line under the name, the
/// haptic, and the stage's reaction (only for things that worked). Shared by the watch and phone.
public struct CareEvent: Equatable {
    public let id = UUID()
    public let message: String
    public let feedback: SensoryFeedback
    /// Only successful taps make the pet react.
    public let reaction: StageReaction?

    public init(action: CareAction, outcome: CareOutcome, petName: String, itemName: String?) {
        let gain = Int((outcome.changes[action.stat] ?? 0).rounded())
        reaction = StageReaction(id: id, action: action, floater: "\(action.emoji) +\(gain)")
        let thing = itemName.map { "the \($0.lowercased())" } ?? "that"
        switch outcome.reaction {
        case .loved:
            message = "\(petName) loves \(thing)! 💕"
            feedback = .success
        case .enjoyed:
            message = "\(petName) enjoyed \(thing)!"
            feedback = .impact(weight: .medium)
        case .meh:
            message = action == .feed ? "Picky… \(petName) only nibbled it." : "\(petName) wasn't that into it."
            feedback = .impact(weight: .light)
        case .unwell:
            message = "\(petName) feels a little better."
            feedback = .impact(weight: .light)
        }
    }

    public init(gift: PetMoment, petName: String) {
        reaction = StageReaction(id: id, action: nil, floater: "\(gift.isLucky ? "🪙" : "🎁") +\(gift.pep)")
        message = gift.isLucky ? "Lucky! \(petName) found \(gift.find)! 🪙" : "\(petName) found \(gift.find)! 🎁"
        feedback = .success
    }

    public init(action: CareAction, failure: QuickCareError, petName: String) {
        reaction = nil
        feedback = .error
        switch failure {
        case .alreadySatisfied(.hunger): message = "\(petName) is already full!"
        case .alreadySatisfied(.happiness): message = "\(petName) is already having a blast!"
        case .alreadySatisfied(.cleanliness): message = "\(petName) is already squeaky clean!"
        case .alreadySatisfied(.energy): message = "\(petName) isn't sleepy."
        case .cantAfford(let price): message = "Need \(price) Pep. Time for a walk!"
        case .noItem, .care: message = "\(petName) can't do that right now."
        }
    }

    public static func == (lhs: CareEvent, rhs: CareEvent) -> Bool { lhs.id == rhs.id }
}
