/// Overall state of a pet, derived from its stats and how long it has been neglected.
public enum PetCondition: String, Codable, CaseIterable, Sendable {
    case thriving
    case content
    case sad
    /// Neglected for a while; care is less effective until it recovers.
    case sick
    /// About to run away. Final warning.
    case packing
    /// Gone until the player completes a comeback quest. The pet is never lost for good.
    case ranAway

    public var acceptsCare: Bool { self != .ranAway }
}
