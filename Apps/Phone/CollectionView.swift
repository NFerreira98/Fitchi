import FitchiCore
import FitchiData
import FitchiUI
import SwiftUI

/// Every species and colouring, Pokédex-style: found ones in colour, the rest as silhouettes.
struct CollectionView: View {
    @Environment(PetStore.self) private var pets

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 12)]

    var body: some View {
        let book = pets.collection
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FitchiTheme.Spacing.l * 1.5) {
                    progress(book)
                    ForEach(book.species) { page in
                        VStack(alignment: .leading, spacing: FitchiTheme.Spacing.s) {
                            header(page)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(page.entries) { entry in
                                    CollectionCard(
                                        entry: entry, species: page.species, speciesDiscovered: page.isDiscovered)
                                }
                            }
                        }
                    }
                }
                .padding(FitchiTheme.Spacing.l)
            }
            .navigationTitle("Collection")
        }
    }

    private func progress(_ book: CollectionBook) -> some View {
        VStack(alignment: .leading, spacing: FitchiTheme.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(book.foundCount) of \(book.totalCount) found")
                    .font(FitchiTheme.Fonts.display(.title3))
                Spacer()
                Text("✨ \(book.shiniesFound) shiny")
                    .font(FitchiTheme.Fonts.display(.subheadline))
                    .foregroundStyle(CollectionCard.gold)
            }
            ProgressView(value: Double(book.foundCount), total: Double(max(book.totalCount, 1)))
                .tint(FitchiTheme.Colors.accent)
            Text(
                "Hatch eggs to find new pets and colours. Shinies turn up 1 in 64. "
                    + "\(book.specialsFound) of \(book.specialsTotal) specials found: they only hatch in certain "
                    + "weather (🌧️ ❄️ 💨), at certain times (🌅 🌆 🌙) or seasons (🌸 🍂)."
            )
            .font(FitchiTheme.Fonts.text(.footnote))
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func header(_ page: CollectionBook.Page) -> some View {
        HStack(spacing: FitchiTheme.Spacing.s) {
            Text(page.isDiscovered ? page.species.name : "???")
                .font(FitchiTheme.Fonts.display(.headline))
            Text(page.species.rarity.title)
                .font(FitchiTheme.Fonts.text(.caption2, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(page.species.rarity.color.opacity(0.2), in: .capsule)
                .foregroundStyle(page.species.rarity.color)
            Spacer()
            Text("\(page.foundCount)/\(page.entries.count)")
                .font(FitchiTheme.Fonts.display(.subheadline).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
