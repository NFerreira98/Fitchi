/// How rare a species is. Starter eggs only hatch `.common` species.
public enum Rarity: String, Codable, CaseIterable, Sendable, Comparable, CodingKeyRepresentable {
    case common
    case uncommon
    case rare
    case epic
    case legendary

    private var rank: Int {
        switch self {
        case .common: 0
        case .uncommon: 1
        case .rare: 2
        case .epic: 3
        case .legendary: 4
        }
    }

    public static func < (lhs: Rarity, rhs: Rarity) -> Bool {
        lhs.rank < rhs.rank
    }
}
