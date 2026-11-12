import FitchiCore
import FitchiData
import FitchiUI
import SwiftUI
import WidgetKit

/// The pet on the watch face: its face shows how it feels, a ring shows overall wellbeing.
///
/// The watch app writes a `PetGlance` after every change. Stats are computed from timestamps,
/// so the timeline can look hours ahead without the app running.
struct PetMoodWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PetMood", provider: PetMoodProvider()) { entry in
            PetMoodView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Your Pet")
        .description("See how your pet is feeling, and when it needs you.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct PetMoodEntry: TimelineEntry {
    let date: Date
    let glance: PetGlance

    var pet: Pet? { glance.pet }

    private var context: DecayContext { DecayContext() }

    var mood: PetMood { pet.map { $0.mood(at: date, in: context) } ?? .content }
    var wellbeing: Double { pet.map { $0.wellbeing(at: date, in: context) } ?? 0 }
    var values: [Stat: Double] { pet.map { $0.values(at: date, in: context) } ?? [:] }

    /// A still frame of the pet showing its mood (no walking on a watch face).
    var frame: PetFrame {
        PetLife.frame(at: 0, seed: PetLife.seed(for: pet?.id), mood: mood, wander: false, still: true)
    }

    static let preview = PetMoodEntry(date: .now, glance: .empty)
}

struct PetMoodProvider: TimelineProvider {
    /// Entries every 20 minutes for the next 12 hours; the app reloads the timeline on changes.
    static let step: TimeInterval = 20 * 60
    static let span: TimeInterval = 12 * 3600

    func placeholder(in context: Context) -> PetMoodEntry { .preview }

    func getSnapshot(in context: Context, completion: @escaping (PetMoodEntry) -> Void) {
        completion(PetMoodEntry(date: .now, glance: GlanceStore.load() ?? .empty))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PetMoodEntry>) -> Void) {
        let glance = GlanceStore.load() ?? .empty
        let now = Date.now
        let entries = stride(from: 0, through: Self.span, by: Self.step).map {
            PetMoodEntry(date: now.addingTimeInterval($0), glance: glance)
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(Self.span))))
    }
}

struct PetMoodView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PetMoodEntry

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .accessoryCorner: corner
        default: circular
        }
    }

    @ViewBuilder private var figure: some View {
        if let pet = entry.pet, let species = entry.glance.species, PetFigure.hasArt(for: pet.speciesID) {
            PetFigure(
                speciesID: pet.speciesID, palette: PetPalette(species: species, variant: pet.variant),
                pose: entry.frame.pose, effects: entry.frame.effects, accessories: pet.equipped)
        } else if let species = entry.glance.species {
            Text(species.emoji ?? "🐾").font(.system(size: 22))
        } else {
            EggFigure()
        }
    }

    private var circular: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.2), lineWidth: 3.5)
            if entry.pet != nil {
                Circle()
                    .trim(from: 0, to: max(0.02, entry.wellbeing / 100))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .widgetAccentable()
            }
            figure.padding(7)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    private var rectangular: some View {
        HStack(spacing: 6) {
            figure.frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.pet?.name ?? "Your egg")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .lineLimit(1)
                    .widgetAccentable()
                Text(entry.pet.map { _ in entry.mood.headline } ?? "Move to hatch it")
                    .font(.system(.caption2, design: .rounded))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                if entry.pet != nil {
                    HStack(spacing: 3) {
                        ForEach(Stat.allCases, id: \.self) { stat in
                            MiniBar(value: entry.values[stat] ?? 0, color: stat.color)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
    }

    private var inline: some View {
        Text(summary)
    }

    private var corner: some View {
        Text(entry.glance.species?.emoji ?? "🥚")
            .font(.system(size: 20))
            .widgetLabel {
                if entry.pet != nil {
                    Gauge(value: entry.wellbeing, in: 0...100) { Text(entry.pet?.name ?? "") }
                        .tint(ringColor)
                } else {
                    Text("Egg")
                }
            }
    }

    private var summary: String {
        guard let pet = entry.pet else { return "Your egg is waiting" }
        return "\(pet.name) · \(entry.mood.headline)"
    }

    private var ringColor: Color {
        switch entry.wellbeing {
        case ..<35: .red
        case ..<65: .orange
        default: .green
        }
    }
}

/// A tiny stat bar for the rectangular complication.
private struct MiniBar: View {
    let value: Double
    let color: Color

    var body: some View {
        Capsule()
            .fill(color.opacity(0.25))
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule().fill(color).frame(width: geometry.size.width * max(0.06, min(value / 100, 1)))
                }
            }
            .frame(height: 4)
    }
}
