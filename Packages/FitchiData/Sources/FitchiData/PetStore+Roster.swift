import FitchiCore
import Foundation

extension PetStore {
    /// Stars (or unstars) a pet for the showcase. Saved on the pet, so it rides along with the
    /// watch backup like its name and outfit.
    public func setFavorite(_ petID: UUID, _ isFavorite: Bool) {
        guard var pet = roster[petID], pet.isFavorite != isFavorite else { return }
        pet.isFavorite = isFavorite
        try? roster.update(pet)
        try? repository?.save(pet, at: clock.now)
        didChange()
    }

    /// The roster at a glance, for the Pets tab.
    public var rosterStats: RosterStats { RosterStats(pets: roster.pets, catalog: catalog) }
}
