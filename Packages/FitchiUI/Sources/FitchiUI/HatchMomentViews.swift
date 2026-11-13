import FitchiCore
import SwiftUI

extension HatchCondition {
    /// "❄️", "🌙", "🍂": the badge on a special colouring.
    public var emoji: String {
        if let weather { return weather.emoji }
        if let time { return time.emoji }
        return season?.emoji ?? "✨"
    }

    /// "Snow only", "Night only": short enough for a collection card.
    public var short: String {
        let what = weather?.title ?? time?.title ?? season?.title ?? "Special"
        return "\(what) only"
    }

    /// "Only hatches in the snow", for VoiceOver and the hatch screen.
    public var hint: String {
        if let weather {
            return switch weather {
            case .rain: "Only hatches in the rain"
            case .snow: "Only hatches in the snow"
            case .wind: "Only hatches on a windy spell"
            case .cloudy: "Only hatches on a grey day"
            case .clear: "Only hatches in fair weather"
            }
        }
        if let time { return "Only hatches at \(time.title.lowercased())" }
        if let season { return "Only hatches in \(season.title.lowercased())" }
        return "A special colouring"
    }
}

extension Weather.Kind {
    public var emoji: String {
        switch self {
        case .clear: "☀️"
        case .cloudy: "☁️"
        case .rain: "🌧️"
        case .wind: "💨"
        case .snow: "❄️"
        }
    }

    public var title: String {
        switch self {
        case .clear: "Fair"
        case .cloudy: "Grey"
        case .rain: "Rain"
        case .wind: "Wind"
        case .snow: "Snow"
        }
    }
}

extension TimeOfDay {
    public var emoji: String {
        switch self {
        case .dawn: "🌅"
        case .day: "☀️"
        case .dusk: "🌆"
        case .night: "🌙"
        }
    }

    public var title: String {
        switch self {
        case .dawn: "Dawn"
        case .day: "Daytime"
        case .dusk: "Dusk"
        case .night: "Night"
        }
    }
}

extension Season {
    public var emoji: String {
        switch self {
        case .spring: "🌸"
        case .summer: "🌻"
        case .autumn: "🍂"
        case .winter: "⛄️"
        }
    }

    public var title: String { rawValue.capitalized }
}

extension HatchMoment {
    /// "🌧️ Rain · 🌙 Night · 🍂 Autumn"
    public var summary: String {
        var parts: [String] = []
        if weather != .clear { parts.append("\(weather.emoji) \(weather.title)") }
        parts.append("\(time.emoji) \(time.title)")
        parts.append("\(season.emoji) \(season.title)")
        return parts.joined(separator: " · ")
    }
}

/// What the world is like right now and what that means for eggs: special colourings that can
/// hatch, and species that turn up more often. Shown above the eggs in the shop.
public struct HatchMomentBanner: View {
    private let moment: HatchMoment
    private let catalog: Catalog
    private let found: Set<String>

    /// - Parameter found: collection ids already found (`Species.collectionID(for:)`).
    public init(moment: HatchMoment, catalog: Catalog, found: Set<String>) {
        self.moment = moment
        self.catalog = catalog
        self.found = found
    }

    public var body: some View {
        let specials = catalog.species.flatMap { species in
            species.specialVariants.filter { $0.when?.matches(moment) == true }.map { (species, $0) }
        }
        let unfound = specials.count { !found.contains($0.0.collectionID(for: PetVariant(id: $0.1.id))) }
        let favoured = catalog.species.filter { $0.affinity(at: moment) > 1 }
        VStack(alignment: .leading, spacing: 6) {
            Text("Right now: \(moment.summary)")
                .font(FitchiTheme.Fonts.display(.subheadline))
            if specials.isEmpty {
                Text("Nothing special is hatching. Rain, snow, wind, dawn, dusk and night bring rare colourings.")
            } else {
                let emojis = Set(specials.compactMap { $0.1.when?.emoji }).sorted().joined(separator: " ")
                Text(
                    "\(emojis) \(specials.count) special colouring\(specials.count == 1 ? "" : "s") can hatch now"
                        + (unfound > 0 ? " (\(unfound) still to find)." : ". You've found them all!"))
            }
            if !favoured.isEmpty {
                Text("More likely now: \(favoured.map(\.name).joined(separator: ", ")).")
                    .foregroundStyle(.secondary)
            }
        }
        .font(FitchiTheme.Fonts.text(.footnote))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
