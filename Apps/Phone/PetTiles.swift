import FitchiCore
import FitchiData
import FitchiUI
import SwiftUI

/// A pet in its colouring and outfit, gently alive (or still, where many are drawn small).
struct PetPortrait: View {
    @Environment(PetStore.self) private var pets
    let pet: Pet
    var animated = true

    var body: some View {
        if let species = pets.species(of: pet), PetFigure.hasArt(for: pet.speciesID) {
            if animated {
                // Alive but light: 12 fps, and its personality shows now and then.
                LivingPetView(
                    species: species, speciesID: pet.speciesID, variant: pet.variant, seed: pet.id,
                    accessories: pet.equipped, personality: pet.personality, framesPerSecond: 12)
            } else {
                PetFigure(
                    speciesID: pet.speciesID, palette: PetPalette(species: species, variant: pet.variant),
                    accessories: pet.equipped)
            }
        } else {
            Text(pets.species(of: pet)?.emoji ?? "🐾").font(.system(size: 40))
        }
    }
}

/// Badges that make a pet stand out: favourite, shiny or special, and whether it's on the watch.
struct PetBadges: View {
    @Environment(PetStore.self) private var pets
    let pet: Pet

    var body: some View {
        HStack(spacing: 3) {
            if pet.isFavorite { Image(systemName: "star.fill").foregroundStyle(.yellow) }
            if pet.isShiny { Text("✨") }
            if let condition = pets.catalog.colouring(of: pet)?.when, !pet.isShiny { Text(condition.emoji) }
            if pet.isActive { Image(systemName: "applewatch").foregroundStyle(.green) }
        }
        .font(.system(size: 13, weight: .semibold))
    }
}

/// A grid card: portrait, badges, name and colouring.
struct PetTile: View {
    @Environment(PetStore.self) private var pets
    let pet: Pet

    var body: some View {
        let species = pets.species(of: pet)
        VStack(spacing: 4) {
            PetPortrait(pet: pet)
                .padding(10)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill((species?.rarity.color ?? .gray).opacity(0.16))
                )
                .overlay {
                    if pet.isShiny {
                        RoundedRectangle(cornerRadius: 16).strokeBorder(CollectionCard.gold, lineWidth: 2)
                    }
                }
                .overlay(alignment: .topTrailing) { PetBadges(pet: pet).padding(6) }
            Text(pet.name)
                .font(FitchiTheme.Fonts.display(.subheadline))
                .lineLimit(1)
            Text(pets.catalog.colouring(of: pet)?.name ?? species?.name ?? "")
                .font(FitchiTheme.Fonts.text(.caption2, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PetTile.description(of: pet, pets: pets))
    }

    static func description(of pet: Pet, pets: PetStore) -> String {
        let species = pets.species(of: pet)?.name ?? pet.speciesID
        let colouring = pets.catalog.colouring(of: pet)?.name ?? ""
        let extras = [
            pet.isFavorite ? "favourite" : nil, pet.isShiny ? "shiny" : nil,
            pets.catalog.colouringKind(of: pet) == .special ? "special" : nil, pet.isActive ? "on your watch" : nil,
        ].compactMap { $0 }
        return ([pet.name, "\(colouring) \(species)"] + extras).joined(separator: ", ")
    }
}

/// A list row: more detail per pet, for scanning.
struct PetRow: View {
    @Environment(PetStore.self) private var pets
    let pet: Pet

    var body: some View {
        let species = pets.species(of: pet)
        HStack(spacing: FitchiTheme.Spacing.m) {
            PetPortrait(pet: pet)
                .frame(width: 54, height: 54)
                .padding(4)
                .background((species?.rarity.color ?? .gray).opacity(0.16), in: .rect(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(pet.name).font(FitchiTheme.Fonts.display(.headline))
                    PetBadges(pet: pet)
                }
                Text("\(pets.catalog.colouring(of: pet)?.name ?? "") \(species?.name ?? "")")
                    .font(FitchiTheme.Fonts.text(.subheadline))
                HStack(spacing: 6) {
                    if let rarity = species?.rarity { Text(rarity.title).foregroundStyle(rarity.color) }
                    Text("· \(pet.personality.title) · \(pet.hatchedAt.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundStyle(.secondary)
                }
                .font(FitchiTheme.Fonts.text(.caption, weight: .medium))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(.fill.quaternary, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(PetTile.description(of: pet, pets: pets))
    }
}

/// The roster at a glance: totals worth showing off.
struct RosterStatsHeader: View {
    let stats: RosterStats

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FitchiTheme.Spacing.s) {
                tile("\(stats.pets)", stats.pets == 1 ? "pet" : "pets", "pawprint.fill", .orange)
                tile("\(stats.speciesOwned)/\(stats.speciesTotal)", "species", "square.grid.2x2.fill", .teal)
                tile("\(stats.shinies)", "shiny", "sparkles", CollectionCard.gold)
                tile("\(stats.specials)", "special", "cloud.moon.fill", .indigo)
                tile("\(stats.favourites)", "favourites", "star.fill", .yellow)
            }
        }
        .scrollClipDisabled()
        .accessibilityElement(children: .combine)
    }

    private func tile(_ value: String, _ label: String, _ symbol: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(value).font(FitchiTheme.Fonts.display(.title3).monospacedDigit())
            Text(label).font(FitchiTheme.Fonts.text(.caption, weight: .medium)).foregroundStyle(.secondary)
        }
        .frame(minWidth: 72, alignment: .leading)
        .padding(12)
        .background(.fill.tertiary, in: .rect(cornerRadius: 16))
    }
}
