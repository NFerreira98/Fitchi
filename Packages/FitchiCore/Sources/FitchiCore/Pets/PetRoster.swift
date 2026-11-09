import Foundation

/// The player's collection of pets. Exactly one pet is active (shown on the watch) at a time.
public struct PetRoster: Codable, Hashable, Sendable {
    public private(set) var pets: [Pet]

    public init(pets: [Pet] = []) {
        self.pets = pets
    }

    public var activePet: Pet? { pets.first { $0.isActive } }

    public subscript(id: UUID) -> Pet? {
        pets.first { $0.id == id }
    }

    /// Adds a newly hatched pet. The first pet ever added becomes active.
    public mutating func add(_ pet: Pet, at date: Date, in context: DecayContext) {
        var pet = pet
        pet.setActive(pets.isEmpty, at: date, in: context)
        pets.append(pet)
    }

    /// Makes `id` the active pet; the previous active pet starts resting (slower decay).
    public mutating func setActive(_ id: UUID, at date: Date, in context: DecayContext) throws(RosterError) {
        guard pets.contains(where: { $0.id == id }) else { throw .unknownPet }
        for index in pets.indices {
            pets[index].setActive(pets[index].id == id, at: date, in: context)
        }
    }

    /// Replaces a pet with an updated copy (e.g. after care).
    public mutating func update(_ pet: Pet) throws(RosterError) {
        guard let index = pets.firstIndex(where: { $0.id == pet.id }) else { throw .unknownPet }
        pets[index] = pet
    }
}

public enum RosterError: Error, Equatable {
    case unknownPet
}
