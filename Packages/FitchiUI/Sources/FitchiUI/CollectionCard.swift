import FitchiCore
import SwiftUI

/// One slot in the collection book: the pet in that colouring once found, a dark silhouette
/// until then. Shinies get a gold frame and sparkles.
public struct CollectionCard: View {
    private let entry: CollectionEntry
    private let species: Species
    /// Undiscovered species keep even their name secret.
    private let speciesDiscovered: Bool

    public init(entry: CollectionEntry, species: Species, speciesDiscovered: Bool) {
        self.entry = entry
        self.species = species
        self.speciesDiscovered = speciesDiscovered
    }

    public var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(background)
                figure
                    .padding(10)
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if entry.isShiny {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(entry.isFound ? Self.gold : Self.gold.opacity(0.35), lineWidth: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                // Special colourings wear their condition, found or not: a clue where to look.
                if let condition = entry.condition {
                    Text(condition.emoji)
                        .font(.system(size: 15))
                        .padding(5)
                }
            }
            Text(title)
                .font(FitchiTheme.Fonts.display(.caption, weight: .bold))
                .foregroundStyle(entry.isFound ? (entry.isShiny ? Self.gold : .primary) : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let condition = entry.condition, !entry.isFound {
                Text(condition.short)
                    .font(FitchiTheme.Fonts.text(.caption2, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    public static let gold = Color(red: 0.95, green: 0.72, blue: 0.15)
    static let silhouetteColor = Color(red: 0.23, green: 0.21, blue: 0.31)

    private var title: String {
        if entry.isFound { return entry.isShiny ? "✨ \(entry.name)" : entry.name }
        return entry.isShiny ? "✨ ???" : "???"
    }

    private var background: Color {
        entry.isFound ? Color(red: 0.84, green: 0.93, blue: 0.99) : Color(white: 0.5, opacity: 0.12)
    }

    @ViewBuilder private var figure: some View {
        if PetFigure.hasArt(for: species.id) {
            if entry.isFound {
                // Found ones are alive (gently: a grid of them is on screen at once).
                LivingPetView(
                    species: species, speciesID: species.id, variant: entry.variant, seedValue: seed,
                    framesPerSecond: 12)
            } else {
                // A solid "who's that?" shape: no eyes, blush or markings give it away.
                Self.silhouetteColor.mask(
                    PetFigure(speciesID: species.id, palette: PetPalette(species: species, variant: entry.variant)))
            }
        } else {
            Text(species.emoji ?? "🐾")
                .font(.system(size: 40))
                .brightness(entry.isFound ? 0 : -1)
                .opacity(entry.isFound ? 1 : 0.55)
        }
    }

    /// A steady seed from the entry's id, so neighbours don't breathe in step.
    private var seed: Double {
        Double(entry.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 10_007 }) / 97
    }

    private var accessibilityText: String {
        let special = entry.condition.map { ". \($0.hint)" } ?? ""
        guard entry.isFound else {
            return
                (speciesDiscovered
                ? "\(species.name), \(entry.isShiny ? "shiny, " : "")not found yet" : "Undiscovered") + special
        }
        let found = entry.foundAt.map { ", found \($0.formatted(date: .abbreviated, time: .omitted))" } ?? ""
        return "\(entry.isShiny ? "Shiny " : "")\(entry.name) \(species.name)\(found)\(special)"
    }
}

extension Rarity {
    public var title: String {
        switch self {
        case .common: "Common"
        case .uncommon: "Uncommon"
        case .rare: "Rare"
        case .epic: "Epic"
        case .legendary: "Legendary"
        }
    }

    public var color: Color {
        switch self {
        case .common: Color(red: 0.45, green: 0.7, blue: 0.45)
        case .uncommon: Color(red: 0.3, green: 0.6, blue: 0.9)
        case .rare: Color(red: 0.6, green: 0.4, blue: 0.9)
        case .epic: Color(red: 0.9, green: 0.4, blue: 0.6)
        case .legendary: Color(red: 0.95, green: 0.65, blue: 0.1)
        }
    }
}
