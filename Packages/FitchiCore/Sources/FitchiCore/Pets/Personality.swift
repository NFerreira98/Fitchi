/// A personality quirk rolled at hatch time. It nudges decay rates and how much the pet
/// enjoys different kinds of care.
public enum Personality: String, Codable, CaseIterable, Sendable {
    case easygoing
    case glutton
    case couchPotato
    case neatFreak
    case hyper
    case pickyEater

    /// Extra multiplier on the decay rate of `stat`.
    public func decayMultiplier(for stat: Stat) -> Double {
        switch (self, stat) {
        case (.easygoing, _): 0.95
        case (.glutton, .hunger): 1.25
        case (.couchPotato, .energy): 0.8
        case (.couchPotato, .happiness): 1.1
        case (.neatFreak, .cleanliness): 0.8
        case (.hyper, .energy): 1.25
        case (.hyper, .happiness): 0.9
        default: 1.0
        }
    }

    /// Multiplier on the *positive* effects of an item of `category`.
    public func careMultiplier(for category: ItemCategory, isFavorite: Bool) -> Double {
        let favoriteBonus = isFavorite ? 1.25 : 1.0
        switch (self, category) {
        case (.pickyEater, .food), (.pickyEater, .treat): return isFavorite ? 1.5 : 0.75
        case (.glutton, .food), (.glutton, .treat): return 1.1 * favoriteBonus
        case (.hyper, .toy): return 1.2 * favoriteBonus
        case (.couchPotato, .toy): return 0.8 * favoriteBonus
        case (.couchPotato, .rest): return 1.2 * favoriteBonus
        case (.neatFreak, .hygiene): return 1.2 * favoriteBonus
        default: return favoriteBonus
        }
    }
}
