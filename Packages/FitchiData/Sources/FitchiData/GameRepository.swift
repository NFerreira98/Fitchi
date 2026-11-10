import FitchiCore
import Foundation
import SwiftData

/// Loads and saves game state. Reads tolerate duplicates by keeping the newest record per id.
@MainActor
public struct GameRepository {
    private let container: ModelContainer
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(container: ModelContainer) {
        self.container = container
    }

    private var context: ModelContext { container.mainContext }

    public func loadPets() throws -> [Pet] {
        let records = try context.fetch(FetchDescriptor<PetRecord>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))
        var seen = Set<String>()
        return records
            .filter { seen.insert($0.petID).inserted }
            .compactMap { try? decoder.decode(Pet.self, from: $0.payload) }
            .sorted { $0.hatchedAt < $1.hatchedAt }
    }

    public func save(_ pet: Pet, at date: Date) throws {
        let id = pet.id.uuidString
        let payload = try encoder.encode(pet)
        let existing = try context.fetch(FetchDescriptor<PetRecord>(predicate: #Predicate { $0.petID == id }))
        if let record = existing.first {
            record.payload = payload
            record.updatedAt = date
            existing.dropFirst().forEach(context.delete)
        } else {
            context.insert(PetRecord(petID: id, payload: payload, updatedAt: date))
        }
        try context.save()
    }

    public func loadStarterEgg() throws -> StarterEgg? {
        let records = try context.fetch(FetchDescriptor<StarterEggRecord>())
        let eggs = records.compactMap { try? decoder.decode(StarterEgg.self, from: $0.payload) }
        // After a merge, a hatched egg beats an unhatched one, then the earliest grant wins.
        return eggs.min { ($0.isHatched ? 0 : 1, $0.grantedAt) < ($1.isHatched ? 0 : 1, $1.grantedAt) }
    }

    public func save(_ egg: StarterEgg, at date: Date) throws {
        let payload = try encoder.encode(egg)
        let existing = try context.fetch(FetchDescriptor<StarterEggRecord>())
        if let record = existing.first {
            record.payload = payload
            record.updatedAt = date
            existing.dropFirst().forEach(context.delete)
        } else {
            context.insert(StarterEggRecord(payload: payload, updatedAt: date))
        }
        try context.save()
    }

    // MARK: - Pep ledger (append-only)

    public func loadTransactions() throws -> [PepTransaction] {
        let records = try context.fetch(FetchDescriptor<LedgerRecord>(sortBy: [SortDescriptor(\.date)]))
        var seen = Set<String>()
        return records
            .filter { seen.insert($0.entryID).inserted }
            .compactMap { try? decoder.decode(PepTransaction.self, from: $0.payload) }
    }

    /// Appends transactions that aren't recorded yet. Existing entries are never touched.
    public func append(_ transactions: [PepTransaction]) throws {
        let known = Set(try context.fetch(FetchDescriptor<LedgerRecord>()).map(\.entryID))
        for transaction in transactions where !known.contains(transaction.id) {
            context.insert(
                LedgerRecord(entryID: transaction.id, payload: try encoder.encode(transaction), date: transaction.date)
            )
        }
        try context.save()
    }

    // MARK: - Inventory

    public func loadInventory() throws -> Inventory? {
        let records = try context.fetch(
            FetchDescriptor<InventoryRecord>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        )
        return records.lazy.compactMap { try? decoder.decode(Inventory.self, from: $0.payload) }.first
    }

    public func save(_ inventory: Inventory, at date: Date) throws {
        let payload = try encoder.encode(inventory)
        let existing = try context.fetch(FetchDescriptor<InventoryRecord>())
        if let record = existing.first {
            record.payload = payload
            record.updatedAt = date
            existing.dropFirst().forEach(context.delete)
        } else {
            context.insert(InventoryRecord(payload: payload, updatedAt: date))
        }
        try context.save()
    }
}
