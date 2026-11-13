import FitchiCore
import FitchiData
import FitchiUI
import SwiftUI

/// Every pet you own, to browse and show off: search, quick filters, a full filter sheet, sorting,
/// a grid or a list, and sections per species. Tap a pet for its page.
struct PetsView: View {
    @Environment(PetStore.self) private var pets
    @AppStorage("fitchi.pets.layout") private var layout = Layout.grid
    @AppStorage("fitchi.pets.grouped") private var grouped = false
    @AppStorage("fitchi.pets.sort") private var sort = RosterQuery.Sort.newest
    @State private var query = RosterQuery()
    @State private var showsFilters = false
    @State private var collapsed: Set<String> = []

    enum Layout: String {
        case grid, list
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FitchiTheme.Spacing.l) {
                    RosterStatsHeader(stats: pets.rosterStats)
                    quickFilters
                    results
                }
                .padding(FitchiTheme.Spacing.l)
            }
            .navigationTitle("Pets")
            .searchable(text: $query.text, prompt: "Name, species or colour")
            .toolbar { toolbar }
            .navigationDestination(for: UUID.self) { PetPage(petID: $0) }
            .sheet(isPresented: $showsFilters) {
                PetFilterSheet(query: $query, catalog: pets.catalog, owned: Set(pets.roster.pets.map(\.speciesID)))
                    .presentationDetents([.medium, .large])
            }
            .onAppear { query.sort = sort }
            .onChange(of: sort) { query.sort = sort }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(RosterQuery.Sort.allCases, id: \.self) { option in
                        Text(option.title).tag(option)
                    }
                }
                Toggle("Favourites first", isOn: $query.favouritesFirst)
                Toggle("Group by species", isOn: $grouped)
                Picker("Show as", selection: $layout) {
                    Label("Grid", systemImage: "square.grid.2x2").tag(Layout.grid)
                    Label("List", systemImage: "list.bullet").tag(Layout.list)
                }
            } label: {
                Label("Sort and view", systemImage: "arrow.up.arrow.down.circle")
            }
            Button {
                showsFilters = true
            } label: {
                Label(
                    "Filters",
                    systemImage: query.activeFilterCount > 0
                        ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
            .badge(query.activeFilterCount)
        }
    }

    // MARK: - Quick filters

    /// One-tap filters for the things people look for most, plus a chip per species owned.
    private var quickFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FitchiTheme.Spacing.s) {
                if query.activeFilterCount > 0 {
                    FilterChip(title: "Clear", systemImage: "xmark", isOn: false) { query.clearFilters() }
                }
                FilterChip(title: "Favourites", systemImage: "star.fill", isOn: query.favouritesOnly) {
                    query.favouritesOnly.toggle()
                }
                FilterChip(title: "✨ Shiny", isOn: query.kinds.contains(.shiny)) { query.kinds.toggle(.shiny) }
                FilterChip(title: "🌙 Special", isOn: query.kinds.contains(.special)) { query.kinds.toggle(.special) }
                ForEach(pets.catalog.species.filter { owned.contains($0.id) }) { species in
                    FilterChip(
                        title: "\(species.emoji ?? "") \(species.name)", isOn: query.species.contains(species.id)
                    ) {
                        query.species.toggle(species.id)
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    private var owned: Set<String> { Set(pets.roster.pets.map(\.speciesID)) }

    // MARK: - Results

    @ViewBuilder private var results: some View {
        let all = pets.roster.pets
        let matching = query.apply(to: all, in: pets.catalog)
        if matching.isEmpty {
            ContentUnavailableView {
                Label(all.isEmpty ? "No pets yet" : "No matches", systemImage: "pawprint")
            } description: {
                Text(all.isEmpty ? "Hatch an egg to start your collection." : "Try fewer filters or another search.")
            } actions: {
                if query.activeFilterCount > 0 { Button("Clear filters") { query.clearFilters() } }
            }
        } else if grouped {
            ForEach(query.grouped(all, in: pets.catalog)) { group in
                section(group)
            }
        } else {
            Text(matching.count == all.count ? "\(all.count) pets" : "\(matching.count) of \(all.count) pets")
                .font(FitchiTheme.Fonts.text(.footnote, weight: .semibold))
                .foregroundStyle(.secondary)
            collection(matching)
        }
    }

    private func section(_ group: RosterGroup) -> some View {
        let isCollapsed = collapsed.contains(group.id)
        let shelf = ColouringShelf(species: group.species, pets: pets.roster.pets)
        return VStack(alignment: .leading, spacing: FitchiTheme.Spacing.s) {
            Button {
                withAnimation(.snappy) { collapsed.toggle(group.id) }
            } label: {
                HStack {
                    Text("\(group.species.emoji ?? "") \(group.species.name)")
                        .font(FitchiTheme.Fonts.display(.headline))
                    Text("\(group.pets.count)")
                        .font(FitchiTheme.Fonts.display(.subheadline).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(shelf.ownedCount)/\(shelf.slots.count) colourings")
                        .font(FitchiTheme.Fonts.text(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            if !isCollapsed { collection(group.pets) }
        }
    }

    @ViewBuilder private func collection(_ list: [Pet]) -> some View {
        switch layout {
        case .grid:
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
                ForEach(list) { pet in
                    NavigationLink(value: pet.id) { PetTile(pet: pet) }
                        .buttonStyle(.plain)
                        .contextMenu { PetMenu(pet: pet) }
                }
            }
        case .list:
            LazyVStack(spacing: 8) {
                ForEach(list) { pet in
                    NavigationLink(value: pet.id) { PetRow(pet: pet) }
                        .buttonStyle(.plain)
                        .contextMenu { PetMenu(pet: pet) }
                }
            }
        }
    }
}

extension RosterQuery.Sort {
    var title: String {
        switch self {
        case .newest: "Newest"
        case .oldest: "Oldest"
        case .name: "Name"
        case .rarity: "Rarity"
        case .species: "Species"
        }
    }
}

extension Set {
    mutating func toggle(_ member: Element) {
        if contains(member) { remove(member) } else { insert(member) }
    }
}

/// Favourite and send-to-watch, from a long press on a pet.
struct PetMenu: View {
    @Environment(PetStore.self) private var pets
    let pet: Pet

    var body: some View {
        Button {
            pets.setFavorite(pet.id, !pet.isFavorite)
        } label: {
            Label(pet.isFavorite ? "Unfavourite" : "Favourite", systemImage: pet.isFavorite ? "star.slash" : "star")
        }
        if !pet.isActive {
            Button {
                pets.setActive(pet.id)
            } label: {
                Label("Send to watch", systemImage: "applewatch")
            }
        }
    }
}

/// A pill that filters on and off.
struct FilterChip: View {
    let title: String
    var systemImage: String?
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(FitchiTheme.Fonts.text(.subheadline, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isOn ? AnyShapeStyle(FitchiTheme.Colors.accent) : AnyShapeStyle(.fill.tertiary), in: .capsule)
            .foregroundStyle(isOn ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
