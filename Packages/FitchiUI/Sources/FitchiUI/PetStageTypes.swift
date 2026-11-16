import FitchiCore
import SwiftUI

/// How the pet screen is arranged. A display preference (Settings), not a purchase: some people
/// find one layout easier to read or calmer to look at than another.
public enum PetLayoutStyle: String, CaseIterable, Identifiable, Sendable {
    /// The pet on a glowing patch of its world, on black. Calm and high-contrast.
    case island
    /// The world fills the screen and fades into black behind the controls.
    case fullScene
    /// The world across the top, stats and controls on plain black below. Easiest to read.
    case horizon

    public var id: String { rawValue }

    /// UserDefaults key for `@AppStorage`.
    public static let storageKey = "fitchi.petLayoutStyle"

    public var title: String {
        switch self {
        case .island: "Island"
        case .fullScene: "Full scene"
        case .horizon: "Horizon"
        }
    }

    public var summary: String {
        switch self {
        case .island: "Your pet on a glowing patch of its world. Calm, high contrast."
        case .fullScene: "The whole screen is your pet's world."
        case .horizon: "Scene on top, stats and buttons on black. Easiest to read."
        }
    }
}

/// A care moment the stage acts out (a bowl, a ball, bubbles or a nap) with a reward floating up.
public struct StageReaction: Equatable, Sendable {
    public let id: UUID
    /// nil for a generic happy wiggle.
    public let action: CareAction?
    public let floater: String
    public let startedAt: Date

    public init(id: UUID = UUID(), action: CareAction? = nil, floater: String, startedAt: Date = .now) {
        self.id = id
        self.action = action
        self.floater = floater
        self.startedAt = startedAt
    }
}
