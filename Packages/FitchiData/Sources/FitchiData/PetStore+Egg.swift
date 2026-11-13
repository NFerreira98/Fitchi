import FitchiCore
import Foundation

extension PetStore {
    /// Gives a brand-new player their starter egg. The iPhone calls this once it knows there's no
    /// Apple Watch (it's then the pet's home); otherwise the watch grants it.
    public func grantStarterEggIfNew() {
        guard status == .ready, let repository, starterEgg == nil, roster.pets.isEmpty else { return }
        try? grantStarterEgg(in: repository)
        didChange()
    }

    func grantStarterEgg(in repository: GameRepository) throws {
        guard starterEgg == nil, roster.pets.isEmpty else { return }
        let egg = StarterEgg(grantedAt: clock.now)
        try repository.save(egg, at: clock.now)
        starterEgg = egg
    }
}
