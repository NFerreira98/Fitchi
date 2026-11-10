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
    /// Pep spent and granted outside of activity (welcome bonus, purchases). Append-only.
    public private(set) var transactions: [PepTransaction] = []
    public private(set) var inventory = Inventory()

    public let catalog: Catalog
    public let decay: DecayContext
    public let hatchRules: HatchRules
    public let pointsRules: PointsRules
    private let repository: GameRepository?
    private let clock: any GameClock

    public init(
        repository: GameRepository?,
        catalog: Catalog,
        decay: DecayContext = DecayContext(),
        hatchRules: HatchRules = .v1,
        pointsRules: PointsRules = .v1,
        clock: any GameClock = SystemClock()
    ) {
        self.repository = repository
        self.catalog = catalog
        self.decay = decay
        self.hatchRules = hatchRules
        self.pointsRules = pointsRules
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
            transactions = try repository.loadTransactions()
            if !transactions.contains(where: { $0.kind == .welcomeBonus }) {
                let bonus = PepTransaction.welcomeBonus(pointsRules.welcomeBonus, at: clock.now)
                try repository.append([bonus])
                transactions.append(bonus)
            }
            inventory = try repository.loadInventory() ?? Inventory()
            status = .ready
        } catch {
            status = .failed("Couldn't open your saved pets.")
        }
    }

    /// The Pep balance: activity earnings (from Health) plus this ledger.
    public func wallet(earnings: [Earning]) -> Wallet {
        Wallet(earnings: earnings, transactions: transactions)
    }

    /// One-tap care. Buys the item if needed, applies it, and saves everything.
    @discardableResult
    public func care(_ action: CareAction, for petID: UUID, earnings: [Earning]) throws(QuickCareError) -> CareOutcome {
        guard var pet = roster[petID] else { throw .noItem }
        var wallet = wallet(earnings: earnings)
        var inventory = inventory
        let now = clock.now
        let outcome = try QuickCare.perform(
            action, on: &pet, catalog: catalog,
            wallet: &wallet, inventory: &inventory, at: now, in: decay
        )
        let newTransactions = wallet.transactions.filter { new in !transactions.contains { $0.id == new.id } }
        try? roster.update(pet)
        self.inventory = inventory
        transactions.append(contentsOf: newTransactions)
        try? repository?.append(newTransactions)
        try? repository?.save(inventory, at: now)
        try? repository?.save(pet, at: now)
        return outcome
    }

    /// The item a care tap would use right now, for showing its price.
    public func careItem(_ action: CareAction, for pet: Pet, earnings: [Earning]) -> ShopItem? {
        guard let species = species(of: pet) else { return nil }
        return QuickCare.item(
            for: action, species: species, catalog: catalog,
            inventory: inventory, balance: wallet(earnings: earnings).balance
        )
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
