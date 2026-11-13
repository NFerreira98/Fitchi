import FitchiCore
import FitchiData
import FitchiHealth
import FitchiUI
import SwiftUI

/// Today's quests and the streak on the phone's Home tab, plus a nudge when the pet has a gift
/// waiting on the watch.
struct PhoneQuestsCard: View {
    @Environment(PetStore.self) private var pets
    @Environment(ActivityStore.self) private var activity
    let petName: String
    @State private var hatched: HatchedPet?
    @State private var problem: String?

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            VStack(alignment: .leading, spacing: FitchiTheme.Spacing.m) {
                ForEach(pets.rewardEggs) { reward in
                    rewardEggRow(reward)
                }
                if pets.openMoment(at: timeline.date) != nil {
                    Label(
                        "\(petName) found something! Tap the gift by your pet to collect it.", systemImage: "gift.fill"
                    )
                    .font(FitchiTheme.Fonts.text(.subheadline, weight: .semibold))
                    .foregroundStyle(FitchiTheme.Colors.points)
                }
                HStack {
                    Text("Today's quests").font(FitchiTheme.Fonts.display(.title3))
                    Spacer()
                }
                StreakLadderView(streak: pets.questStreak, todayDone: pets.questsDoneToday)
                ForEach(pets.todaysQuests(samples: activity.samples, steps: activity.steps)) { status in
                    QuestRow(
                        goal: status.quest.goal, reward: status.quest.reward, current: status.current,
                        target: status.target, petName: petName)
                }
                Text(
                    "Finish all three each day to climb the ladder: more Pep every day, then a free egg on day 7 "
                        + "(a Golden Egg every 4th week). One missed day won't reset it."
                )
                .font(FitchiTheme.Fonts.text(.footnote))
                .foregroundStyle(.secondary)
            }
            .padding(FitchiTheme.Spacing.l)
            .background(.fill.tertiary, in: .rect(cornerRadius: 20))
        }
        .fullScreenCover(item: $hatched) { hatched in
            PhoneHatchView(pet: hatched.pet, isNewFind: hatched.isNewFind, refund: hatched.refund)
        }
        .alert(
            "Couldn't hatch the egg", isPresented: Binding(get: { problem != nil }, set: { if !$0 { problem = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(problem ?? "")
        }
    }

    /// "You earned a Sparkle Egg!" with a Hatch button.
    private func rewardEggRow(_ reward: PetStore.RewardEgg) -> some View {
        HStack(spacing: FitchiTheme.Spacing.m) {
            EggFigure().frame(width: 40, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("You earned a \(reward.egg.name)!").font(FitchiTheme.Fonts.display(.headline))
                Text("Your streak reward. It's free to hatch.")
                    .font(FitchiTheme.Fonts.text(.caption))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Hatch") {
                do throws(PetStore.PurchaseError) {
                    let hatch = try pets.hatchRewardEgg(reward)
                    hatched = HatchedPet(pet: hatch.pet, isNewFind: hatch.isNewFind, refund: hatch.refund)
                } catch {
                    problem = "Please try again."
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(FitchiTheme.Colors.accent)
        }
        .padding(FitchiTheme.Spacing.m)
        .background(FitchiTheme.Colors.points.opacity(0.18), in: .rect(cornerRadius: 14))
    }
}
