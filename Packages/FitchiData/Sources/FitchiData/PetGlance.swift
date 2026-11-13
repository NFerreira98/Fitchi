import FitchiCore
import Foundation

/// What the watch-face complication needs to draw the pet: the active pet and its species (for
/// colours). Stats are computed from the pet's timestamps, so one glance stays accurate for
/// hours; the app rewrites it after every change.
public struct PetGlance: Codable, Hashable, Sendable {
    public var pet: Pet?
    public var species: Species?
    /// True while the starter egg is still waiting to hatch.
    public var hasEgg: Bool
    /// Ledger ids of gifts already collected, so the complication only hints at waiting ones.
    /// Optional so glances saved by older versions still decode.
    public var collectedGifts: Set<String>?

    public init(pet: Pet?, species: Species?, hasEgg: Bool, collectedGifts: Set<String> = []) {
        self.pet = pet
        self.species = species
        self.hasEgg = hasEgg
        self.collectedGifts = collectedGifts
    }

    /// Whether a gift is waiting at `date` (the pet must be around to have found it).
    public func hasGift(at date: Date, calendar: Calendar = .current) -> Bool {
        guard pet != nil, let moment = PetMoments.open(at: date, calendar: calendar) else { return false }
        return !(collectedGifts ?? []).contains(moment.id)
    }

    public static let empty = PetGlance(pet: nil, species: nil, hasEgg: true)
}

/// Shares the glance between the watch app and its complication through their App Group.
public enum GlanceStore {
    public static let appGroup = "group.com.nicholasferreira.fitchi"
    static let key = "fitchi.glance"

    public static func save(_ glance: PetGlance, to defaults: UserDefaults? = UserDefaults(suiteName: appGroup)) {
        guard let data = try? JSONEncoder().encode(glance) else { return }
        defaults?.set(data, forKey: key)
    }

    public static func load(from defaults: UserDefaults? = UserDefaults(suiteName: appGroup)) -> PetGlance? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PetGlance.self, from: data)
    }
}

public extension PetStore {
    var glance: PetGlance {
        PetGlance(
            pet: activePet, species: activePet.flatMap(species(of:)), hasEgg: pendingEgg != nil,
            collectedGifts: Set(collectedGiftIDs))
    }
}
