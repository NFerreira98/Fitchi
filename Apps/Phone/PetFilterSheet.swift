import FitchiCore
import FitchiUI
import SwiftUI

/// Every filter in one place: species, rarity, colouring type, personality and favourites.
/// Changes apply as you tap.
struct PetFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var query: RosterQuery
    let catalog: Catalog
    /// Species you own; the rest aren't worth filtering by.
    let owned: Set<String>

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Favourites only", systemImage: "star.fill", isOn: $query.favouritesOnly)
                }
                Section("Species") {
                    chips(catalog.species.filter { owned.contains($0.id) }, selection: $query.species) {
                        ($0.id, "\($0.emoji ?? "") \($0.name)")
                    }
                }
                Section("Rarity") {
                    chips(Rarity.allCases, selection: $query.rarities) { ($0, $0.title) }
                }
                Section {
                    chips(ColouringKind.allCases, selection: $query.kinds) { ($0, $0.title) }
                } header: {
                    Text("Colouring")
                } footer: {
                    Text("Special colourings only hatch in certain weather, at certain times or in certain seasons.")
                }
                Section("Personality") {
                    chips(Personality.allCases, selection: $query.personalities) { ($0, $0.title) }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear") { query.clearFilters() }
                        .disabled(query.activeFilterCount == 0)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// A wrapping set of chips for picking any number of `options`.
    private func chips<Option, Key: Hashable>(
        _ options: [Option], selection: Binding<Set<Key>>, label: @escaping (Option) -> (Key, String)
    ) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let (key, title) = label(option)
                FilterChip(title: title, isOn: selection.wrappedValue.contains(key)) {
                    selection.wrappedValue.toggle(key)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

extension ColouringKind {
    var title: String {
        switch self {
        case .regular: "Regular"
        case .special: "🌙 Special"
        case .shiny: "✨ Shiny"
        }
    }
}

/// Lays children out left to right, wrapping onto new lines.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var items: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if let last = rows.last, !last.items.isEmpty, last.width + spacing + size.width > width {
                rows.append(Row(y: last.y + last.height + spacing))
            }
            rows[rows.count - 1].items.append(index)
            let current = rows[rows.count - 1]
            rows[rows.count - 1].width = current.items.count == 1 ? size.width : current.width + spacing + size.width
            rows[rows.count - 1].height = max(current.height, size.height)
        }
        return rows
    }
}
