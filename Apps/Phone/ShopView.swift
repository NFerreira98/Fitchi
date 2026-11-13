import FitchiCore
import FitchiData
import FitchiHealth
import FitchiUI
import SwiftUI

/// Spend Pep on eggs and backdrops. Food and toys are bought with a tap on the watch, where
/// they're used; art styles show as coming soon until they're drawn.
struct ShopView: View {
    @Environment(PetStore.self) private var pets
    @Environment(ActivityStore.self) private var activity
    @State private var eggToBuy: EggType?
    @State private var hatched: HatchedPet?
    @State private var problem: String?

    private var balance: Int { pets.wallet(earnings: activity.earnings).balance }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("\(balance) Pep", systemImage: "sparkles")
                        .font(FitchiTheme.Fonts.display(.title2).monospacedDigit())
                        .foregroundStyle(FitchiTheme.Colors.points)
                        .accessibilityLabel("Balance: \(balance) Pep")
                }
                eggs
                backdrops
                accessories
                comingSoon
            }
            .navigationTitle("Shop")
            .confirmationDialog(
                eggToBuy.map { "Buy a \($0.name) for \($0.price) Pep?" } ?? "",
                isPresented: Binding(get: { eggToBuy != nil }, set: { if !$0 { eggToBuy = nil } }),
                titleVisibility: .visible, presenting: eggToBuy
            ) { egg in
                Button("Buy and hatch") { buy(egg) }
            } message: { _ in
                Text("It hatches right away. New pets rest until you make them your active pet.")
            }
            .alert("Can't buy that", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(problem ?? "")
            }
            .fullScreenCover(item: $hatched) { hatched in
                PhoneHatchView(pet: hatched.pet, isNewFind: hatched.isNewFind, refund: hatched.refund)
            }
        }
    }

    // MARK: - Eggs

    private var eggs: some View {
        Section {
            // What can hatch right now changes with the weather and the time of day.
            TimelineView(.everyMinute) { _ in
                HatchMomentBanner(
                    moment: pets.hatchMoment, catalog: pets.catalog,
                    found: Set(pets.collection.entries.filter(\.isFound).map(\.id)))
            }
            ForEach(pets.catalog.eggs) { egg in
                HStack(spacing: FitchiTheme.Spacing.m) {
                    EggFigure().frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(egg.name).font(FitchiTheme.Fonts.display(.headline))
                        Text(odds(egg)).font(FitchiTheme.Fonts.text(.caption)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    PriceButton(price: egg.price, affordable: balance >= egg.price) { eggToBuy = egg }
                }
            }
        } header: {
            Text("Eggs")
        } footer: {
            Text(
                "Each egg hatches a surprise pet, with the odds shown. Any pet can be shiny (1 in 64). "
                    + "Eggs favour colourings you haven't found, and a repeat gives 25% of its price back. "
                    + "Some colourings only hatch in rain, snow or wind, or at dawn, dusk or night.")
        }
    }

    private func odds(_ egg: EggType) -> String {
        Rarity.allCases.compactMap { rarity in
            guard let percent = egg.displayOdds[rarity], percent > 0 else { return nil }
            return "\(rarity.title) \(percent.formatted(.number.precision(.significantDigits(1...2))))%"
        }
        .joined(separator: " · ")
    }

    private func buy(_ egg: EggType) {
        do {
            let hatch = try pets.buyEgg(egg, earnings: activity.earnings)
            hatched = HatchedPet(pet: hatch.pet, isNewFind: hatch.isNewFind, refund: hatch.refund)
        } catch {
            problem = message(for: error)
        }
    }

    // MARK: - Backdrops

    private var backdrops: some View {
        Section {
            backdropRow(id: Catalog.defaultBackdropID, name: "Meadow", price: nil)
            ForEach(pets.catalog.items.filter { $0.category == .backdrop }) { item in
                backdropRow(id: item.id, name: item.name, price: item.price)
            }
        } header: {
            Text("Backdrops")
        } footer: {
            Text("Backdrops work with every pet, everywhere you play.")
        }
    }

    private func backdropRow(id: String, name: String, price: Int?) -> some View {
        let owned = price == nil || pets.inventory.owns(id)
        let inUse = pets.inventory.activeBackdropID == id
        return HStack(spacing: FitchiTheme.Spacing.m) {
            SceneBackdrop(id: id)
                .frame(width: 72, height: 48)
                .clipShape(.rect(cornerRadius: 10))
            Text(name).font(FitchiTheme.Fonts.display(.headline))
            Spacer()
            if inUse {
                Label("In use", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(FitchiTheme.Fonts.text(.subheadline, weight: .semibold))
                    .foregroundStyle(.green)
            } else if owned {
                Button("Use") { pets.selectBackdrop(id) }
                    .buttonStyle(.bordered)
            } else if let price, let item = pets.catalog.item(id: id) {
                PriceButton(price: price, affordable: balance >= price) {
                    do throws(PetStore.PurchaseError) {
                        try pets.buy(item, earnings: activity.earnings)
                        pets.selectBackdrop(id)
                    } catch {
                        problem = message(for: error)
                    }
                }
            }
        }
    }

    // MARK: - Accessories

    private var accessories: some View {
        Section {
            ForEach(pets.catalog.items.filter { $0.category == .accessory }) { item in
                accessoryRow(item)
            }
        } header: {
            Text("Accessories")
        } footer: {
            if let pet = pets.activePet {
                Text("Shown on \(pet.name). Buy once, wear on any pet; change outfits here or on your watch.")
            }
        }
    }

    private func accessoryRow(_ item: ShopItem) -> some View {
        let pet = pets.activePet
        let wearing = pet.map { $0.equipped[item.slot ?? .head] == item.id } ?? false
        return HStack(spacing: FitchiTheme.Spacing.m) {
            AccessoryPreview(item: item)
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(FitchiTheme.Fonts.display(.headline))
                Text(item.description).font(FitchiTheme.Fonts.text(.caption)).foregroundStyle(.secondary)
            }
            Spacer()
            if !pets.inventory.owns(item.id) {
                PriceButton(price: item.price, affordable: balance >= item.price) {
                    do throws(PetStore.PurchaseError) {
                        try pets.buy(item, earnings: activity.earnings)
                        if let pet { pets.wear(item.id, on: pet.id) }
                    } catch {
                        problem = message(for: error)
                    }
                }
            } else if let pet, let slot = item.slot {
                Button(wearing ? "Take off" : "Wear") {
                    if wearing { pets.takeOff(slot, from: pet.id) } else { pets.wear(item.id, on: pet.id) }
                }
                .buttonStyle(.bordered)
                .tint(wearing ? .secondary : FitchiTheme.Colors.accent)
            }
        }
    }

    // MARK: - Coming soon

    private var comingSoon: some View {
        Section {
            ForEach(pets.catalog.items.filter { $0.category == .artStyle }) { item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(FitchiTheme.Fonts.display(.subheadline))
                        Text(item.description).font(FitchiTheme.Fonts.text(.caption)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(item.price)").font(FitchiTheme.Fonts.display(.subheadline).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .opacity(0.6)
            }
        } header: {
            Text("Coming soon")
        } footer: {
            Text("Art styles go on sale once they're drawn.")
        }
    }

    private func message(for error: PetStore.PurchaseError) -> String {
        switch error {
        case .shop(.insufficientFunds(let price, let balance)):
            "That costs \(price) Pep and you have \(balance). A walk will get you there!"
        case .shop(.alreadyOwned): "You already own that."
        case .hatch: "That egg couldn't hatch. Please try again."
        case .notSaved: "Couldn't save the purchase. Please try again."
        }
    }
}

struct HatchedPet: Identifiable {
    let pet: Pet
    let isNewFind: Bool
    let refund: Int
    var id: UUID { pet.id }
}

/// "✦ 600" buy button, dimmed when you can't afford it.
struct PriceButton: View {
    let price: Int
    let affordable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("✦ \(price)")
                .font(FitchiTheme.Fonts.display(.subheadline).monospacedDigit())
        }
        .buttonStyle(.borderedProminent)
        .tint(affordable ? FitchiTheme.Colors.accent : .gray)
        .accessibilityLabel("Buy for \(price) Pep")
        .accessibilityHint(affordable ? "" : "Not enough Pep yet")
    }
}

/// The active pet wearing one accessory (on top of its current outfit), or the item's name if
/// there's no pet to dress.
private struct AccessoryPreview: View {
    @Environment(PetStore.self) private var pets
    let item: ShopItem

    var body: some View {
        if let pet = pets.activePet, let species = pets.species(of: pet), let slot = item.slot {
            PetFigure(
                speciesID: pet.speciesID, palette: PetPalette(species: species, variant: pet.variant),
                accessories: pet.equipped.merging([slot: item.id]) { _, new in new })
        } else {
            Image(systemName: "tshirt.fill").font(.title2).foregroundStyle(.secondary)
        }
    }
}
