import FitchiCore
import FitchiData
import FitchiHealth
import FitchiUI
import SwiftUI

/// Today's three quests and the streak. New quests every day at midnight.
struct WatchQuestsView: View {
    @Environment(PetStore.self) private var pets
    @Environment(ActivityStore.self) private var activity

    var body: some View {
        // Re-reads every minute so time-boxed quests and the day change stay current.
        TimelineView(.everyMinute) { _ in
            let quests = pets.todaysQuests(samples: activity.samples, steps: activity.steps)
            let name = pets.activePet?.name ?? "your pet"
            ScrollView {
                VStack(alignment: .leading, spacing: FitchiTheme.Spacing.m) {
                    StreakLadderView(streak: pets.questStreak, todayDone: pets.questsDoneToday, compact: true)
                    ForEach(quests) { status in
                        QuestRow(
                            goal: status.quest.goal, reward: status.quest.reward, current: status.current,
                            target: status.target, petName: name, compact: true)
                    }
                    Text(footer(quests))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, FitchiTheme.Spacing.s)
            }
        }
    }

    private func footer(_ quests: [QuestStatus]) -> String {
        let left = quests.count { !$0.isDone }
        return left == 0
            ? "All done for today! New quests at midnight."
            : "Finish all \(quests.count) to climb the ladder. Day 7 is a free egg; missing one day won't reset it."
    }
}
