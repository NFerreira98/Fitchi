import FitchiCore
import FitchiData
import FitchiUI
import SwiftUI

/// One pet's page: living in its scene, everything about it, and its species' colourings side by
/// side (yours, how many of each, and what's still to find).
struct PetPage: View {
    @Environment(PetStore.self) private var pets
    let petID: UUID
    @State private var name = ""
    @State private var comparing: PetsView.CompareRequest?

    var body: some View {
        if let pet = pets.roster[petID], let species = pets.species(of: pet) {
            ScrollView {
                VStack(alignment: .leading, spacing: FitchiTheme.Spacing.l) {
                    TimelineView(.periodic(from: .now, by: 60)) { timeline in
                        PetStage(
                            pet: pet, species: species, mood: pet.mood(at: timeline.date, in: pets.decay),
                            backdrop: SceneBackdrop.Kind(id: pets.inventory.activeBackdropID), style: .fullScene,
                            petScale: 0.4, controlsBelow: false)
                    }
                    .aspectRatio(1.3, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 24))
                    header(pet, species)
                    facts(pet, species)
                    traits(pet)
                    PetVoiceRow(voice: PetVoice(petID: pet.id, speciesID: pet.speciesID), petName: pet.name)
                        .padding(12)
                        .background(.fill.tertiary, in: .rect(cornerRadius: 14))
                    ColouringShelfView(shelf: ColouringShelf(species: species, pets: pets.roster.pets), current: pet.id)
                }
                .padding(FitchiTheme.Spacing.l)
            }
            .navigationTitle(pet.name)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $comparing) { PetCompareView(petIDs: $0.pets) }
            .toolbar {
                compareMenu(pet)
                Button {
                    pets.setFavorite(pet.id, !pet.isFavorite)
                } label: {
                    Label("Favourite", systemImage: pet.isFavorite ? "star.fill" : "star")
                }
                .tint(.yellow)
                .sensoryFeedback(.selection, trigger: pet.isFavorite)
            }
            .onAppear { name = pet.name }
        } else {
            ContentUnavailableView("Pet not found", systemImage: "pawprint")
        }
    }

    /// Pick another pet to put side by side with this one (same species first).
    private func compareMenu(_ pet: Pet) -> some View {
        let others = pets.roster.pets.filter { $0.id != pet.id }.sorted {
            ($0.speciesID == pet.speciesID ? 0 : 1, $0.name) < ($1.speciesID == pet.speciesID ? 0 : 1, $1.name)
        }
        return Menu {
            ForEach(others) { other in
                Button("\(other.name) · \(pets.species(of: other)?.name ?? "")") {
                    comparing = PetsView.CompareRequest(pets: [pet.id, other.id])
                }
            }
        } label: {
            Label("Compare with…", systemImage: "rectangle.split.2x1")
        }
        .disabled(others.isEmpty)
    }

    private func header(_ pet: Pet, _ species: Species) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Name", text: $name)
                .font(FitchiTheme.Fonts.display(.title))
                .submitLabel(.done)
                .onSubmit { pets.rename(pet.id, to: name) }
            HStack(spacing: 8) {
                Text("\(pets.catalog.colouring(of: pet)?.name ?? "") \(species.name)")
                Text(species.rarity.title).foregroundStyle(species.rarity.color)
                PetBadges(pet: pet)
            }
            .font(FitchiTheme.Fonts.text(.subheadline, weight: .semibold))
            if let condition = pets.catalog.colouring(of: pet)?.when, !pet.isShiny {
                Text("\(condition.emoji) \(condition.hint)")
                    .font(FitchiTheme.Fonts.text(.footnote, weight: .semibold))
                    .foregroundStyle(.indigo)
            }
            if pet.isActive {
                Label("Living on your watch", systemImage: "applewatch").foregroundStyle(.green)
                    .font(FitchiTheme.Fonts.text(.footnote, weight: .semibold))
            } else {
                Button("Send to watch", systemImage: "applewatch") { pets.setActive(pet.id) }
                    .buttonStyle(.borderedProminent)
                    .tint(FitchiTheme.Colors.accent)
            }
        }
    }

    private func facts(_ pet: Pet, _ species: Species) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Personality") {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(pet.personality.title)
                    Text(pet.personality.blurb).font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            LabeledContent("Hatched", value: pet.hatchedAt.formatted(date: .long, time: .shortened))
            let worn = AccessorySlot.allCases.compactMap { pet.equipped[$0] }.compactMap {
                pets.catalog.item(id: $0)?.name
            }
            LabeledContent("Wearing", value: worn.isEmpty ? "Nothing yet" : worn.joined(separator: ", "))
        }
        .font(FitchiTheme.Fonts.text(.subheadline))
        .padding(12)
        .background(.fill.tertiary, in: .rect(cornerRadius: 14))
    }

    private func traits(_ pet: Pet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Traits").font(FitchiTheme.Fonts.display(.headline))
            ForEach(
                [
                    ("Appetite", pet.traits.appetite), ("Playfulness", pet.traits.playfulness),
                    ("Stamina", pet.traits.stamina), ("Tidiness", pet.traits.tidiness),
                ], id: \.0
            ) { label, value in
                HStack {
                    Text(label).font(FitchiTheme.Fonts.text(.subheadline)).frame(width: 96, alignment: .leading)
                    ProgressView(value: value).tint(FitchiTheme.Colors.accent)
                }
            }
        }
        .padding(12)
        .background(.fill.tertiary, in: .rect(cornerRadius: 14))
    }
}

/// Every colouring of a species side by side: yours in colour with how many you have, the rest
/// as silhouettes with a hint for special ones. Tap one you own to visit that pet.
struct ColouringShelfView: View {
    @Environment(PetStore.self) private var pets
    let shelf: ColouringShelf
    let current: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(shelf.species.name) colourings").font(FitchiTheme.Fonts.display(.headline))
                Spacer()
                Text("\(shelf.ownedCount)/\(shelf.slots.count)")
                    .font(FitchiTheme.Fonts.display(.subheadline).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 10)], spacing: 10) {
                ForEach(shelf.slots) { slot in
                    // Another pet in this colouring: tap to go and see it.
                    if let other = slot.owned.first(where: { $0.id != current }) {
                        NavigationLink(value: other.id) { card(slot) }.buttonStyle(.plain)
                    } else {
                        card(slot)
                    }
                }
            }
        }
    }

    private func card(_ slot: ColouringShelf.Slot) -> some View {
        let entry = CollectionEntry(
            speciesID: shelf.species.id, variantID: slot.colouring.id, name: slot.colouring.name,
            rarity: shelf.species.rarity, isShiny: slot.isShiny, foundAt: slot.owned.first?.hatchedAt,
            condition: slot.colouring.when)
        return CollectionCard(entry: entry, species: shelf.species, speciesDiscovered: true)
            .overlay(alignment: .topLeading) {
                let isThis = slot.owned.contains { $0.id == current }
                if isThis || slot.owned.count > 1 {
                    // Which one is this pet, and how many of each colouring you have.
                    Text(
                        [isThis ? "This one" : nil, slot.owned.count > 1 ? "×\(slot.owned.count)" : nil]
                            .compactMap { $0 }.joined(separator: " · ")
                    )
                    .font(FitchiTheme.Fonts.display(size: 11, weight: .bold).monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isThis ? AnyShapeStyle(FitchiTheme.Colors.accent) : AnyShapeStyle(.thinMaterial), in: .capsule
                    )
                    .foregroundStyle(isThis ? .white : .primary)
                    .padding(5)
                }
            }
    }
}
