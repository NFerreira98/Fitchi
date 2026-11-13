import Foundation

/// Two or three pets side by side: their traits, how fast their needs run down, and what sets
/// them apart. Pure, so the phone's compare screen only lays it out.
public struct PetComparison: Hashable, Sendable {
    /// One measure across the pets, in the same order as `pets`.
    public struct Row: Hashable, Sendable, Identifiable {
        public var id: String
        public var values: [Double]
        /// Which pet stands out (the highest trait, or the easiest to look after); nil on a tie.
        public var standout: Int?
    }

    public var pets: [Pet]
    /// Appetite, playfulness, stamina, tidiness: 0…1, higher stands out.
    public var traits: [Row]
    /// How fast each need runs down compared with an average pet (1×), from traits and
    /// personality together. Lower is easier, and stands out.
    public var needs: [Row]
    /// Plain-words differences ("Different species", "Same personality").
    public var notes: [String]

    public init(pets: [Pet], catalog: Catalog) {
        self.pets = pets
        traits = [
            ("appetite", pets.map(\.traits.appetite)), ("playfulness", pets.map(\.traits.playfulness)),
            ("stamina", pets.map(\.traits.stamina)), ("tidiness", pets.map(\.traits.tidiness)),
        ].map { id, values in Row(id: id, values: values, standout: Self.standout(values, highest: true)) }
        needs = Stat.allCases.map { stat in
            let values = pets.map { $0.traits.decayMultiplier(for: stat) * $0.personality.decayMultiplier(for: stat) }
            return Row(id: stat.rawValue, values: values, standout: Self.standout(values, highest: false))
        }
        notes = Self.notes(for: pets, catalog: catalog)
    }

    /// The index of the single best value, if one beats the rest by a noticeable margin.
    static func standout(_ values: [Double], highest: Bool) -> Int? {
        guard values.count > 1 else { return nil }
        let order = values.indices.sorted { highest ? values[$0] > values[$1] : values[$0] < values[$1] }
        return abs(values[order[0]] - values[order[1]]) >= 0.02 ? order[0] : nil
    }

    static func notes(for pets: [Pet], catalog: Catalog) -> [String] {
        func same<Value: Hashable>(_ value: (Pet) -> Value) -> Bool { Set(pets.map(value)).count == 1 }
        var notes: [String] = []
        if same(\.speciesID) {
            notes.append(same { catalog.colouring(of: $0)?.id } ? "Same species and colouring" : "Same species")
        } else {
            notes.append("Different species")
        }
        notes.append(same(\.personality) ? "Same personality" : "Different personalities")
        if let oldest = pets.min(by: { $0.hatchedAt < $1.hatchedAt }), !same(\.hatchedAt) {
            notes.append("\(oldest.name) hatched first")
        }
        return notes
    }
}
