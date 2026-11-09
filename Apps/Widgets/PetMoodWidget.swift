import SwiftUI
import WidgetKit

/// Complication showing the pet's mood at a glance. Real data arrives in Milestone 7.
struct PetMoodWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PetMood", provider: PetMoodProvider()) { entry in
            PetMoodView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Pet Mood")
        .description("See how your pet is feeling.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct PetMoodEntry: TimelineEntry {
    let date: Date
    let emoji: String
}

struct PetMoodProvider: TimelineProvider {
    func placeholder(in context: Context) -> PetMoodEntry {
        PetMoodEntry(date: .now, emoji: "🐣")
    }

    func getSnapshot(in context: Context, completion: @escaping (PetMoodEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PetMoodEntry>) -> Void) {
        completion(Timeline(entries: [placeholder(in: context)], policy: .never))
    }
}

struct PetMoodView: View {
    let entry: PetMoodEntry

    var body: some View {
        Text(entry.emoji)
            .font(.title)
    }
}
