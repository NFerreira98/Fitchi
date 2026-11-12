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

    /// Called after anything is saved (hatching, care, renaming, a restore): the backup, the
    /// complication and care reminders all follow along.
    @ObservationIgnored private var changeHandlers: [@MainActor () -> Void] = []

    public func onChange(_ handler: @escaping @MainActor () -> Void) {
        changeHandlers.append(handler)
    }

    private func didChange() {
        for handler in changeHandlers { handler() }
    }

    public init(
        repository: GameRepository?,
        catalog: Catalog,
        decay: DecayContext = DecayContext(),
        hatchRules: HatchRules = .v1,
        pointsRules: PointsRules = .current,
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

    /// Loads saved state. A brand-new player gets their starter egg here, unless
    /// `grantsStarterEgg` is false (the iPhone, which only keeps a backup of the watch's game).
    public func load(grantsStarterEgg: Bool = true) {
        guard !catalog.species.isEmpty else {
            status = .failed("Couldn't load the pet catalog.")
            return
        }
        guard let repository else {
            status = .failed("Couldn't open your saved pets.")
            return
        }
        do {
            try reloadSavedState(from: repository)
            if grantsStarterEgg, starterEgg == nil, roster.pets.isEmpty {
                let egg = StarterEgg(grantedAt: clock.now)
                try repository.save(egg, at: clock.now)
                starterEgg = egg
            }
            if !transactions.contains(where: { $0.kind == .welcomeBonus }) {
                let bonus = PepTransaction.welcomeBonus(pointsRules.welcomeBonus, at: clock.now)
                try repository.append([bonus])
                transactions.append(bonus)
            }
            status = .ready
        } catch {
            status = .failed("Couldn't open your saved pets.")
        }
    }

    private func reloadSavedState(from repository: GameRepository) throws {
        roster = PetRoster(pets: try repository.loadPets())
        starterEgg = try repository.loadStarterEgg()
        transactions = try repository.loadTransactions()
        var inventory = try repository.loadInventory() ?? Inventory()
        // Permanent purchases in the ledger are owned, whatever an older inventory copy says.
        inventory.grantOwnership(of: transactions.compactMap(permanentPurchase))
        self.inventory = inventory
    }

    private func permanentPurchase(_ transaction: PepTransaction) -> String? {
        guard case .purchase(let itemID) = transaction.kind,
            let item = catalog.item(id: itemID), !item.category.isConsumable
        else { return nil }
        return itemID
    }

    // MARK: - Shop and collection

    public enum PurchaseError: Error, Equatable {
        case shop(ShopError)
        case hatch
        case notSaved
    }

    /// Every species and colouring, with the ones this player has found.
    public var collection: CollectionBook {
        CollectionBook(catalog: catalog, pets: roster.pets)
    }

    /// Buys a permanent item (a backdrop, for now).
    public func buy(_ item: ShopItem, earnings: [Earning]) throws(PurchaseError) {
        var wallet = wallet(earnings: earnings)
        var inventory = inventory
        do {
            try Shop.buy(item, wallet: &wallet, inventory: &inventory, at: clock.now)
        } catch {
            throw .shop(error)
        }
        try save(wallet: wallet, inventory: inventory)
        didChange()
    }

    /// Buys and hatches an egg. The pet joins the roster (resting, unless it's the first).
    public func buyEgg(_ egg: EggType, earnings: [Earning]) throws(PurchaseError) -> Pet {
        var wallet = wallet(earnings: earnings)
        var rng = SystemRandomNumberGenerator()
        let now = clock.now
        let pet: Pet
        do {
            pet = try Shop.buyEgg(egg, from: catalog, wallet: &wallet, at: now, using: &rng)
        } catch let error as ShopError {
            throw .shop(error)
        } catch {
            throw .hatch
        }
        roster.add(pet, at: now, in: decay)
        let saved = roster[pet.id] ?? pet
        try? repository?.save(saved, at: now)
        try save(wallet: wallet, inventory: inventory)
        didChange()
        return saved
    }

    /// Makes a pet the one shown on the watch; the others rest (and decay slower).
    public func setActive(_ petID: UUID) {
        let now = clock.now
        guard (try? roster.setActive(petID, at: now, in: decay)) != nil else { return }
        for pet in roster.pets { try? repository?.save(pet, at: now) }
        didChange()
    }

    /// Switches the scene behind every pet. Returns false if the backdrop isn't owned.
    @discardableResult
    public func selectBackdrop(_ id: String) -> Bool {
        var inventory = inventory
        guard inventory.selectBackdrop(id) else { return false }
        self.inventory = inventory
        try? repository?.save(inventory, at: clock.now)
        didChange()
        return true
    }

    private func save(wallet: Wallet, inventory: Inventory) throws(PurchaseError) {
        let newTransactions = wallet.transactions.filter { new in !transactions.contains { $0.id == new.id } }
        do {
            try repository?.append(newTransactions)
            try repository?.save(inventory, at: clock.now)
        } catch {
            throw .notSaved
        }
        transactions.append(contentsOf: newTransactions)
        self.inventory = inventory
    }

    // MARK: - Backup

    /// Everything saved, for backing up to the other device.
    public func snapshot(installDate: Date?) -> GameSnapshot? {
        try? repository?.snapshot(installDate: installDate)
    }

    /// Merges a backup from the other device into this one. Returns true if anything changed.
    /// If both devices hatched a pet (e.g. the app was reinstalled before the backup arrived),
    /// both are kept and the longest-owned pet stays active.
    @discardableResult
    public func restore(from backup: GameSnapshot) -> Bool {
        guard let repository, let current = snapshot(installDate: backup.installDate) else { return false }
        let merged = current.merged(with: backup)
        guard merged != current else { return false }
        do {
            try repository.apply(merged)
            try reloadSavedState(from: repository)
        } catch {
            return false
        }
        let active = roster.pets.filter(\.isActive)
        if active.count > 1, let keep = active.min(by: { $0.hatchedAt < $1.hatchedAt }) {
            let now = clock.now
            try? roster.setActive(keep.id, at: now, in: decay)
            for pet in active where pet.id != keep.id {
                if let rested = roster[pet.id] { try? repository.save(rested, at: now) }
            }
        }
        if status != .ready, !catalog.species.isEmpty { status = .ready }
        didChange()
        return true
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
        didChange()
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

    public func hatchProgress(samples: [ActivitySample], steps: [StepCount] = []) -> HatchProgress? {
        pendingEgg.map {
            hatchRules.progress(for: $0, samples: samples, steps: steps, at: clock.now, calendar: decay.calendar)
        }
    }

    /// Cracks the starter egg. The pet gets a cute default name the player can change.
    @discardableResult
    public func hatchStarter(
        samples: [ActivitySample], steps: [StepCount] = [], force: Bool = false
    ) throws(HatchFailure) -> Pet {
        guard var egg = pendingEgg else { throw .alreadyHatched }
        guard force || hatchProgress(samples: samples, steps: steps)?.isReady == true else { throw .notReady }

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
        didChange()
        return saved
    }

    /// Renames a pet. Blank names are ignored.
    public func rename(_ petID: UUID, to rawName: String) {
        guard let name = PetName.sanitized(rawName), var pet = roster[petID] else { return }
        pet.name = name
        try? roster.update(pet)
        try? repository?.save(pet, at: clock.now)
        didChange()
    }

    /// Another suggestion from the species' name list, different from `current` when possible.
    public func suggestedName(for pet: Pet, excluding current: String) -> String {
        let names = species(of: pet)?.defaultNames ?? []
        return names.filter { $0 != current }.randomElement() ?? current
    }
}

extension PetStore {
    /// The on-disk store with the catalog bundled in the app's `Content` folder.
    public static func makeDefault(bundle: Bundle = .main, grantsStarterEgg: Bool = true) -> PetStore {
        let empty = Catalog(species: [], items: [], eggs: [], achievements: [])
        let catalog = (try? bundle.url(forResource: "Content", withExtension: nil).map(Catalog.load(from:))) ?? empty
        let repository = (try? FitchiStore.makeContainer()).map(GameRepository.init(container:))
        let store = PetStore(repository: repository, catalog: catalog)
        store.load(grantsStarterEgg: grantsStarterEgg)
        return store
    }
}
