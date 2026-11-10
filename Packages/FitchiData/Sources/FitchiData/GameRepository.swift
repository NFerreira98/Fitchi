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
}
