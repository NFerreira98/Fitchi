import FitchiCore
import Foundation

/// Everything needed to rebuild a player's game on another device: pets, the starter egg, the
/// Pep ledger, inventory and the install date. The watch sends one to the phone after every
/// change; the phone keeps it as a backup and hands it back if the watch app is reinstalled.
///
/// Merging is commutative and idempotent, so copies can bounce between devices in any order:
/// - pets: the most recently saved copy of each pet wins;
/// - starter egg: a hatched egg beats an unhatched one, then the earliest grant;
/// - Pep ledger: the union (it's append-only);
/// - inventory: the most recently saved copy;
/// - install date: the earliest, so activity since the first install keeps earning.
public struct GameSnapshot: Codable, Hashable, Sendable {
    public struct SavedPet: Codable, Hashable, Sendable {
        public var pet: Pet
        public var updatedAt: Date

        public init(pet: Pet, updatedAt: Date) {
            self.pet = pet
            self.updatedAt = updatedAt
        }
    }

    public struct SavedInventory: Codable, Hashable, Sendable {
        public var inventory: Inventory
        public var updatedAt: Date

        public init(inventory: Inventory, updatedAt: Date) {
            self.inventory = inventory
            self.updatedAt = updatedAt
        }
    }

    /// Bump when the shape changes in a way old readers can't handle.
    public static let formatVersion = 1

    public var formatVersion: Int
    public var pets: [SavedPet]
    public var starterEgg: StarterEgg?
    public var transactions: [PepTransaction]
    public var inventory: SavedInventory?
    public var installDate: Date?

    public init(
        pets: [SavedPet] = [], starterEgg: StarterEgg? = nil, transactions: [PepTransaction] = [],
        inventory: SavedInventory? = nil, installDate: Date? = nil
    ) {
        self.formatVersion = Self.formatVersion
        self.pets = pets
        self.starterEgg = starterEgg
        self.transactions = transactions
        self.inventory = inventory
        self.installDate = installDate
        normalize()
    }

    /// True when there's nothing worth backing up yet (a brand-new player with just an egg).
    public var hasPets: Bool { !pets.isEmpty }

    public func merged(with other: GameSnapshot) -> GameSnapshot {
        var byID: [UUID: SavedPet] = [:]
        for saved in pets + other.pets {
            if let existing = byID[saved.pet.id], !Self.isNewer(saved, than: existing) { continue }
            byID[saved.pet.id] = saved
        }
        var transactionsByID: [String: PepTransaction] = [:]
        for transaction in transactions + other.transactions where transactionsByID[transaction.id] == nil {
            transactionsByID[transaction.id] = transaction
        }
        let inventories = [inventory, other.inventory].compactMap { $0 }
        return GameSnapshot(
            pets: Array(byID.values),
            starterEgg: Self.preferredEgg(starterEgg, other.starterEgg),
            transactions: Array(transactionsByID.values),
            inventory: inventories.max {
                ($0.updatedAt, Self.key($0.inventory)) < ($1.updatedAt, Self.key($1.inventory))
            },
            installDate: [installDate, other.installDate].compactMap { $0 }.min()
        )
    }

    /// The same egg rule `GameRepository` uses when reading duplicates.
    static func preferredEgg(_ first: StarterEgg?, _ second: StarterEgg?) -> StarterEgg? {
        [first, second].compactMap { $0 }.min {
            ($0.isHatched ? 0 : 1, $0.grantedAt, $0.hatchedPetID?.uuidString ?? "")
                < ($1.isHatched ? 0 : 1, $1.grantedAt, $1.hatchedPetID?.uuidString ?? "")
        }
    }

    /// Newest save wins; exact ties break on content so every device picks the same copy.
    private static func isNewer(_ candidate: SavedPet, than existing: SavedPet) -> Bool {
        if candidate.updatedAt != existing.updatedAt { return candidate.updatedAt > existing.updatedAt }
        return key(candidate.pet) > key(existing.pet)
    }

    private static func key(_ value: some Encodable) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return (try? encoder.encode(value)).flatMap { String(bytes: $0, encoding: .utf8) } ?? ""
    }

    /// Stable ordering, so equal games compare equal however they were assembled.
    private mutating func normalize() {
        pets.sort { $0.pet.id.uuidString < $1.pet.id.uuidString }
        transactions.sort { $0.id < $1.id }
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> GameSnapshot {
        let snapshot = try JSONDecoder().decode(GameSnapshot.self, from: data)
        guard snapshot.formatVersion <= formatVersion else { throw SnapshotError.newerFormat }
        return snapshot
    }

    public enum SnapshotError: Error {
        case newerFormat
    }
}
