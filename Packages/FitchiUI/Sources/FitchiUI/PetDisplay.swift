import FitchiCore
import SwiftUI

// Player-facing names, icons and colours for Core enums. Core stays UI-free; the words live here.

extension Stat {
    public var title: String {
        switch self {
        case .hunger: "Food"
        case .happiness: "Fun"
        case .energy: "Energy"
        case .cleanliness: "Clean"
        }
    }

    public var systemImage: String {
        switch self {
        case .hunger: "fork.knife"
        case .happiness: "heart.fill"
        case .energy: "bolt.fill"
        case .cleanliness: "drop.fill"
        }
    }

    public var color: Color {
        switch self {
        case .hunger: FitchiTheme.Colors.hunger
        case .happiness: FitchiTheme.Colors.happiness
        case .energy: FitchiTheme.Colors.energy
        case .cleanliness: FitchiTheme.Colors.cleanliness
        }
    }
}

extension PetCondition {
    public var title: String {
        switch self {
        case .thriving: "Thriving"
        case .content: "Content"
        case .sad: "Sad"
        case .sick: "Feeling sick"
        case .packing: "Packing its bags"
        case .ranAway: "Ran away"
        }
    }
}

extension PetMood {
    /// One short line for the pet screen: the most pressing thing about the pet right now.
    public var headline: String {
        switch condition {
        case .ranAway, .packing, .sick: return condition.title
        default: break
        }
        if isAsleep { return "Fast asleep 💤" }
        if isHungry { return "Hungry" }
        if isDirty { return "Needs a bath" }
        if isBored { return "Bored" }
        if isTired { return "Sleepy" }
        return condition.title
    }

    /// The headline, or "Pumped from your workout!" while a happy pet still has the afterglow.
    public func headline(afterglow: Double) -> String {
        let needsNothing = !isAsleep && !isHungry && !isDirty && !isBored && !isTired
        guard afterglow > 0.15, needsNothing, condition == .content || condition == .thriving else { return headline }
        return "Pumped from your workout! 💪"
    }
}

extension Personality {
    public var title: String {
        switch self {
        case .easygoing: "Easygoing"
        case .glutton: "Glutton"
        case .couchPotato: "Couch potato"
        case .neatFreak: "Neat freak"
        case .hyper: "Hyper"
        case .pickyEater: "Picky eater"
        }
    }

    public var blurb: String {
        switch self {
        case .easygoing: "Takes life slow. Everything wears off a little slower."
        case .glutton: "Always hungry, and loves every snack."
        case .couchPotato: "Saves energy but gets bored easily. Loves naps."
        case .neatFreak: "Stays clean longer and adores bath time."
        case .hyper: "Burns energy fast and goes wild for toys."
        case .pickyEater: "Only really enjoys their favourite foods."
        }
    }
}

/// The four stat bars.
public struct StatBarsView: View {
    private let values: [Stat: Double]

    public init(values: [Stat: Double]) {
        self.values = values
    }

    public var body: some View {
        VStack(spacing: FitchiTheme.Spacing.s) {
            ForEach(Stat.allCases, id: \.self) { stat in
                let value = values[stat] ?? 0
                HStack(spacing: FitchiTheme.Spacing.s) {
                    Image(systemName: stat.systemImage)
                        .foregroundStyle(stat.color)
                        .frame(width: 18)
                    ProgressView(value: value, total: 100)
                        .tint(stat.color)
                    Text("\(Int(value.rounded()))")
                        .font(.caption2.monospacedDigit())
                        .frame(width: 26, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(stat.title): \(Int(value.rounded())) out of 100")
            }
        }
    }
}

#Preview {
    StatBarsView(values: [.hunger: 82, .happiness: 64, .energy: 40, .cleanliness: 12])
        .padding()
}

extension CareAction {
    public var title: String {
        switch self {
        case .feed: "Feed"
        case .play: "Play"
        case .wash: "Wash"
        case .rest: "Nap"
        }
    }

    /// Placeholder effect art until sprite animations exist.
    public var emoji: String {
        switch self {
        case .feed: "🍖"
        case .play: "🎾"
        case .wash: "🫧"
        case .rest: "💤"
        }
    }
}
