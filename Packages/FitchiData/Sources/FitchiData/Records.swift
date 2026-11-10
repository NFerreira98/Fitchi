import Foundation
import SwiftData

// SwiftData records. Each stores one FitchiCore value as JSON, so Core owns the shape and
// these stay CloudKit-compatible: every property defaulted, no unique constraints, no
// relationships. Duplicates (e.g. after a sync merge) are resolved in `GameRepository`.

@Model
public final class PetRecord {
    public var petID: String = ""
    public var payload: Data = Data()
    public var updatedAt: Date = Date.distantPast

    public init(petID: String, payload: Data, updatedAt: Date) {
        self.petID = petID
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

@Model
public final class StarterEggRecord {
    public var payload: Data = Data()
    public var updatedAt: Date = Date.distantPast

    public init(payload: Data, updatedAt: Date) {
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

public enum FitchiStore {
    public static let schema = Schema([PetRecord.self, StarterEggRecord.self])

    /// The app's on-device store. iCloud sync is switched on in Milestone 4 (it needs a paid
    /// developer account), which is why the records are already CloudKit-shaped.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
