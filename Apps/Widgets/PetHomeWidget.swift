import FitchiCore
import FitchiData
import FitchiUI
import SwiftUI
import WidgetKit

/// Behind the widget: the pet's own scene, lit for the time of day, on the iPhone Home Screen;
/// nothing on the watch face and Lock Screen (the system tints those).
struct PetMoodBackground: View {
    @Environment(\.widgetFamily) private var family
    let entry: PetMoodEntry

    var body: some View {
        switch family {
        #if os(iOS)
            case .systemSmall, .systemMedium:
                let season = Season(at: entry.date)
                SceneBackdrop(
                    SceneBackdrop.Kind(id: entry.glance.backdropID ?? Catalog.defaultBackdropID),
                    light: SceneLight(at: entry.date), season: season,
                    weather: Weather(at: entry.date, season: season))
        #endif
        default:
            Color.clear
        }
    }
}

#if os(iOS)
    /// The Home Screen widget: the pet standing in its scene with its mood, and (in the wide size)
    /// a bar per need. Shows the egg until it hatches.
    struct PetHomeWidgetView: View {
        let entry: PetMoodEntry
        let wide: Bool

        var body: some View {
            HStack(alignment: .bottom, spacing: 10) {
                PetMoodView(entry: entry).figure
                    .frame(width: wide ? 92 : 78, height: wide ? 92 : 78)
                    .frame(maxWidth: wide ? nil : .infinity)
                    .overlay(alignment: .topTrailing) {
                        if entry.hasGift { Text("🎁").font(.system(size: 18)) }
                    }
                if wide { details }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .overlay(alignment: .topLeading) {
                if !wide { caption.frame(maxWidth: .infinity, alignment: .leading) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(PetMoodView(entry: entry).summary)
        }

        private var caption: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.pet?.name ?? "Your egg")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Text(status)
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .lineLimit(2)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.55), radius: 2)
        }

        private var details: some View {
            VStack(alignment: .leading, spacing: 6) {
                caption
                if entry.pet != nil {
                    ForEach(Stat.allCases, id: \.self) { stat in
                        HStack(spacing: 6) {
                            Image(systemName: stat.systemImage)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 14)
                            MiniBar(value: entry.values[stat] ?? 0, color: stat.color)
                        }
                    }
                }
            }
            .padding(8)
            .background(.black.opacity(0.28), in: .rect(cornerRadius: 12))
        }

        private var status: String {
            guard let pet = entry.pet else { return "Move to hatch it" }
            return entry.hasGift ? "🎁 \(pet.name) found something!" : entry.mood.headline
        }
    }
#endif
