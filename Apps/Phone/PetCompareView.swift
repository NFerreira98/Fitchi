import FitchiCore
import FitchiData
import FitchiUI
import SwiftUI

/// Two or three pets side by side: looks, the facts, traits and how fast their needs run down,
/// with whoever stands out marked. Columns line up so differences read across.
struct PetCompareView: View {
    @Environment(PetStore.self) private var pets
    @Environment(\.dismiss) private var dismiss
    let petIDs: [UUID]

    var body: some View {
        let chosen = petIDs.compactMap { pets.roster[$0] }
        let comparison = PetComparison(pets: chosen, catalog: pets.catalog)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FitchiTheme.Spacing.l) {
                    portraits(chosen)
                    notes(comparison.notes)
                    section("At a glance") {
                        row("Species") { Text(pets.species(of: $0)?.name ?? $0.speciesID) }
                        row("Colouring") { pet in
                            VStack(spacing: 2) {
                                Text(pets.catalog.colouring(of: pet)?.name ?? "")
                                if let condition = pets.catalog.colouring(of: pet)?.when, !pet.isShiny {
                                    Text("\(condition.emoji) \(condition.short)").font(.caption2).foregroundStyle(
                                        .indigo)
                                }
                            }
                        }
                        row("Rarity") { pet in
                            let rarity = pets.species(of: pet)?.rarity ?? .common
                            Text(rarity.title).foregroundStyle(rarity.color)
                        }
                        row("Personality") { Text($0.personality.title) }
                        row("Voice") { pet in
                            let voice = PetVoice(petID: pet.id, speciesID: pet.speciesID)
                            Button {
                                PetSounds.shared.play(.hello, voice: voice)
                            } label: {
                                Label(voice.name, systemImage: "speaker.wave.2.fill").labelStyle(.titleAndIcon)
                            }
                            .buttonStyle(.borderless)
                        }
                        row("Hatched") { Text($0.hatchedAt.formatted(date: .abbreviated, time: .omitted)) }
                    }
                    section("Traits", footer: "★ marks the highest.") {
                        ForEach(comparison.traits) { traitRow($0, chosen) }
                    }
                    section(
                        "Needs",
                        footer: "How fast each need runs down (1× is average). ★ marks the easiest to look after."
                    ) {
                        ForEach(comparison.needs) { needRow($0, chosen) }
                    }
                }
                .padding(FitchiTheme.Spacing.l)
            }
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    // MARK: - Pieces

    private func portraits(_ chosen: [Pet]) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(chosen) { pet in
                VStack(spacing: 4) {
                    PetPortrait(pet: pet)
                        .padding(8)
                        .aspectRatio(1, contentMode: .fit)
                        .background(
                            (pets.species(of: pet)?.rarity.color ?? .gray).opacity(0.16), in: .rect(cornerRadius: 16)
                        )
                        .overlay(alignment: .topTrailing) { PetBadges(pet: pet).padding(6) }
                    Text(pet.name).font(FitchiTheme.Fonts.display(.headline)).lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func notes(_ notes: [String]) -> some View {
        Text(notes.joined(separator: " · "))
            .font(FitchiTheme.Fonts.text(.footnote, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func section<Content: View>(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content)
        -> some View
    {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(FitchiTheme.Fonts.display(.headline))
            content()
            if let footer {
                Text(footer).font(FitchiTheme.Fonts.text(.caption)).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.fill.tertiary, in: .rect(cornerRadius: 16))
    }

    /// A label, then one cell per pet, in columns that line up with the portraits.
    private func row<Cell: View>(_ label: String, @ViewBuilder cell: @escaping (Pet) -> Cell) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(FitchiTheme.Fonts.text(.caption, weight: .semibold)).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 10) {
                ForEach(petIDs.compactMap { pets.roster[$0] }) { pet in
                    cell(pet)
                        .font(FitchiTheme.Fonts.text(.subheadline))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func traitRow(_ trait: PetComparison.Row, _ chosen: [Pet]) -> some View {
        bars(trait.id.capitalized, values: trait.values, standout: trait.standout, maximum: 1) { "\(Int($0 * 100))" }
    }

    private func needRow(_ need: PetComparison.Row, _ chosen: [Pet]) -> some View {
        let title = Stat(rawValue: need.id)?.title ?? need.id.capitalized
        return bars(title, values: need.values, standout: need.standout, maximum: 1.7) {
            String(format: "%.2f×", $0)
        }
    }

    private func bars(
        _ title: String, values: [Double], standout: Int?, maximum: Double, format: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(FitchiTheme.Fonts.text(.caption, weight: .semibold)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: 3) {
                        ProgressView(value: min(value, maximum), total: maximum)
                            .tint(index == standout ? Color.yellow : FitchiTheme.Colors.accent)
                        Text((index == standout ? "★ " : "") + format(value))
                            .font(FitchiTheme.Fonts.display(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(index == standout ? .primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
