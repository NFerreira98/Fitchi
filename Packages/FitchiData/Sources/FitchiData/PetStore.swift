import FitchiCore
import Foundation
import Observation
import SwiftData

/// The player's pets and starter egg, kept on disk. Shared by the watch and phone UIs.
@Observable
@MainActor
public final class PetStore {
    public enum Status: Equatable, Sendable {
        case loading
        case ready
        case failed(String)
    }

    public enum HatchFailure: Error, Equatable {
        case notReady
        case alreadyHatched
        case noSpecies
    }

    public private(set) var status: Status = .loading
    public private(set) var roster = PetRoster()
    public private(set) var starterEgg: StarterEgg?

    public let catalog: Catalog
    public let decay: DecayContext
    public let hatchRules: HatchRules
    private let repository: GameRepository?
    private let clock: any GameClock

    public init(
        repository: GameRepository?,
        catalog: Catalog,
        decay: DecayContext = DecayContext(),
        hatchRules: HatchRules = .v1,
        clock: any GameClock = SystemClock()
    ) {
        self.repository = repository
        self.catalog = catalog
        self.decay = decay
        self.hatchRules = hatchRules
        self.clock = clock
    }

    public var activePet: Pet? { roster.activePet }

    /// The egg, while it still has to hatch.
    public var pendingEgg: StarterEgg? {
        starterEgg.flatMap { $0.isHatched ? nil : $0 }
    }

    public func species(of pet: Pet) -> Species? { catalog.species(id: pet.speciesID) }

    /// Loads saved state. A brand-new player gets their starter egg here.
    public func load() {
        guard !catalog.species.isEmpty else {
            status = .failed("Couldn't load the pet catalog.")
            return
        }
        guard let repository else {
            status = .failed("Couldn't open your saved pets.")
            return
        }
        do {
            let pets = try repository.loadPets()
            roster = PetRoster(pets: pets)
            starterEgg = try repository.loadStarterEgg()
            if starterEgg == nil, pets.isEmpty {
                let egg = StarterEgg(grantedAt: clock.now)
                try repository.save(egg, at: clock.now)
                starterEgg = egg
            }
            status = .ready
        } catch {
            status = .failed("Couldn't open your saved pets.")
        }
    }

    public func hatchProgress(samples: [ActivitySample]) -> HatchProgress? {
        pendingEgg.map { hatchRules.progress(for: $0, samples: samples, at: clock.now, calendar: decay.calendar) }
    }

    /// Cracks the starter egg. The pet gets a cute default name the player can change.
    @discardableResult
    public func hatchStarter(samples: [ActivitySample], force: Bool = false) throws(HatchFailure) -> Pet {
        guard var egg = pendingEgg else { throw .alreadyHatched }
        guard force || hatchProgress(samples: samples)?.isReady == true else { throw .notReady }

        var rng = SystemRandomNumberGenerator()
        let now = clock.now
        let pet: Pet
        do {
            pet = try Hatchery.hatchStarter(from: catalog, at: now, rules: hatchRules, using: &rng)
        } catch {
            throw .noSpecies
        }
        roster.add(pet, at: now, in: decay)
        egg.hatchedPetID = pet.id
        starterEgg = egg
        let saved = roster[pet.id] ?? pet
        try? repository?.save(saved, at: now)
        try? repository?.save(egg, at: now)
        return saved
    }

    /// Renames a pet. Blank names are ignored.
    public func rename(_ petID: UUID, to rawName: String) {
        guard let name = PetName.sanitized(rawName), var pet = roster[petID] else { return }
        pet.name = name
        try? roster.update(pet)
        try? repository?.save(pet, at: clock.now)
    }

    /// Another suggestion from the species' name list, different from `current` when possible.
    public func suggestedName(for pet: Pet, excluding current: String) -> String {
        let names = species(of: pet)?.defaultNames ?? []
        return names.filter { $0 != current }.randomElement() ?? current
    }
}

extension PetStore {
    /// The on-disk store with the catalog bundled in the app's `Content` folder.
    public static func makeDefault(bundle: Bundle = .main) -> PetStore {
        let empty = Catalog(species: [], items: [], eggs: [], achievements: [])
        let catalog = (try? bundle.url(forResource: "Content", withExtension: nil).map(Catalog.load(from:))) ?? empty
        let repository = (try? FitchiStore.makeContainer()).map(GameRepository.init(container:))
        let store = PetStore(repository: repository, catalog: catalog)
        store.load()
        return store
    }
}
