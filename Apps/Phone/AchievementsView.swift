import FitchiCore
import FitchiData
import FitchiHealth
import FitchiUI
import SwiftUI

/// Every achievement with progress towards it, grouped by what it's about.
struct AchievementsView: View {
    @Environment(PetStore.self) private var pets
    @Environment(ActivityStore.self) private var activity

    var body: some View {
        let progress = pets.progress(
            samples: activity.samples, steps: activity.steps, earnings: activity.earnings,
            installDate: activity.installDate)
        let unlocked = pets.unlockedAchievements
        let all = pets.catalog.achievements
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: FitchiTheme.Spacing.s) {
                        Text("\(unlocked.count) of \(all.count) unlocked")
                            .font(FitchiTheme.Fonts.display(.title3))
                        ProgressView(value: Double(unlocked.count), total: Double(max(all.count, 1)))
                            .tint(FitchiTheme.Colors.points)
                        let earned = all.filter { unlocked[$0.id] != nil }.reduce(0) { $0 + $1.reward }
                        Text("✦ \(earned) Pep earned from achievements")
                            .font(FitchiTheme.Fonts.text(.footnote))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                ForEach(AchievementGroup.allCases, id: \.self) { group in
                    let members = all.filter { AchievementGroup(of: $0.criterion) == group }
                    if !members.isEmpty {
                        Section(group.title) {
                            ForEach(members) { achievement in
                                AchievementRow(
                                    achievement: achievement, unlockedAt: unlocked[achievement.id], progress: progress)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Achievements")
        }
    }
}

private struct AchievementRow: View {
    let achievement: Achievement
    let unlockedAt: Date?
    let progress: PlayerProgress

    var body: some View {
        let (current, target) = achievement.criterion.progress(in: progress)
        HStack(spacing: FitchiTheme.Spacing.m) {
            AchievementBadge(achievement, unlocked: unlockedAt != nil)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(achievement.name).font(FitchiTheme.Fonts.display(.headline))
                    Spacer()
                    Text("+\(achievement.reward)")
                        .font(FitchiTheme.Fonts.display(.subheadline).monospacedDigit())
                        .foregroundStyle(unlockedAt == nil ? .secondary : FitchiTheme.Colors.points)
                }
                Text(achievement.description)
                    .font(FitchiTheme.Fonts.text(.subheadline))
                    .foregroundStyle(.secondary)
                if let unlockedAt {
                    Label(
                        "Unlocked \(unlockedAt.formatted(date: .abbreviated, time: .omitted))",
                        systemImage: "checkmark.seal.fill"
                    )
                    .font(FitchiTheme.Fonts.text(.caption, weight: .semibold))
                    .foregroundStyle(.green)
                } else if target > 1 {
                    ProgressView(value: min(current, target), total: target)
                        .tint(FitchiTheme.Colors.accent)
                    Text("\(Self.format(min(current, target))) / \(Self.format(target))")
                        .font(FitchiTheme.Fonts.text(.caption).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    static func format(_ value: Double) -> String {
        Int(value.rounded(.down)).formatted(.number.notation(value >= 100_000 ? .compactName : .automatic))
    }
}

/// Sections of the achievements list.
enum AchievementGroup: CaseIterable {
    case activity, collection, together, home

    init(of criterion: Criterion) {
        switch criterion {
        case .activeMinutes, .workouts, .streakDays, .pepEarned, .steps: self = .activity
        case .petsOwned, .collectionFound, .shiniesFound, .speciesFound, .rarityFound: self = .collection
        case .daysTogether: self = .together
        case .backdropsOwned, .itemsPurchased: self = .home
        }
    }

    var title: String {
        switch self {
        case .activity: "Get moving"
        case .collection: "Collecting"
        case .together: "Together"
        case .home: "Home & shop"
        }
    }
}
