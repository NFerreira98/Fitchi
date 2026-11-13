import FitchiCore
import FitchiData
import FitchiHealth
import FitchiUI
import SwiftUI

/// The pet's screen: the pet living in its scene (wandering, napping, showing its mood), four
/// stat rings and the care buttons, all on one page with no scrolling. The arrangement follows the player's layout preference
/// (About → Display). Stats are computed from time, so the view re-reads them every minute.
struct PetView: View {
    @Environment(PetStore.self) private var pets
    @Environment(ActivityStore.self) private var activity
    @AppStorage(PetLayoutStyle.storageKey) private var style = PetLayoutStyle.island
    let pet: Pet

    /// The latest care tap (or failed tap), driving the hop, floating reward, message and haptic.
    @State private var event: CareEvent?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let values = pet.values(at: timeline.date, in: pets.decay)
            let mood = pet.mood(at: timeline.date, in: pets.decay)
            let balance = pets.wallet(earnings: activity.earnings).balance
            ZStack {
                PetStage(
                    pet: pet, species: pets.species(of: pet), mood: mood,
                    backdrop: SceneBackdrop.Kind(id: pets.inventory.activeBackdropID), style: style,
                    reaction: event?.reaction, petScale: style == .island ? 0.48 : (style == .horizon ? 0.38 : 0.42)
                )
                .ignoresSafeArea()
                VStack(spacing: 0) {
                    header(
                        balance: balance,
                        status: event?.message ?? mood.headline)
                    if let moment = pets.openMoment(at: timeline.date), event == nil {
                        giftButton(moment)
                    }
                    Spacer(minLength: 0)
                    stats(values)
                    careButtons(balance: balance)
                }
                .ignoresSafeArea(edges: .top)
                if pets.celebrations.isEmpty, let notice = pets.questNotices.first {
                    QuestNoticeCard(notice, petName: pet.name, compact: true)
                        .padding(.horizontal, 8)
                        .id(notice.id)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .onTapGesture { pets.dismissQuestNotice() }
                        .task(id: notice.id) {
                            try? await Task.sleep(for: .seconds(3))
                            pets.dismissQuestNotice()
                        }
                }
                if let next = pets.celebrations.first {
                    AchievementCelebration(next, compact: true)
                        .padding(.horizontal, 8)
                        .id(next.id)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                        .onTapGesture { pets.dismissCelebration() }
                        .task(id: next.id) {
                            try? await Task.sleep(for: .seconds(3))
                            pets.dismissCelebration()
                        }
                }
            }
            .animation(.spring(duration: 0.45), value: pets.celebrations.first?.id)
            .animation(.spring(duration: 0.45), value: pets.questNotices.first?.id)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(trigger: event) { _, new in new?.feedback }
        .sensoryFeedback(.success, trigger: pets.celebrations.first?.id) { _, new in new != nil }
        .sensoryFeedback(.success, trigger: pets.questNotices.first?.id) { _, new in new != nil }
        .task(id: event) {
            guard event != nil else { return }
            // Long enough for the care animation (a nap is the longest) to finish.
            try? await Task.sleep(for: .seconds(4.2))
            event = nil
        }
    }

    /// Name (tap for details), Pep balance and a one-line status or reaction.
    private func header(balance: Int, status: String) -> some View {
        NavigationLink {
            PetDetailView(petID: pet.id)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(pet.name)
                    .font(FitchiTheme.Fonts.display(.headline))
                    .lineLimit(1)
                Text("✦ \(balance) Pep")
                    .font(FitchiTheme.Fonts.display(.footnote).monospacedDigit())
                    .foregroundStyle(FitchiTheme.Colors.points)
                    .contentTransition(.numericText(value: Double(balance)))
                    .animation(.snappy, value: balance)
                Text(status)
                    .font(FitchiTheme.Fonts.text(.caption2, weight: .medium))
                    .foregroundStyle(.white.opacity(event == nil ? 0.8 : 1))
                    .lineLimit(2)
                    .contentTransition(.opacity)
                    .animation(.easeInOut, value: status)
            }
            .shadow(color: .black.opacity(0.6), radius: 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 26)  // name sits level with the clock
            .padding(.leading, 12)
            .padding(.trailing, 56)  // keep clear of the clock
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows details about \(pet.name)")
    }

    @ViewBuilder
    private func stats(_ values: [Stat: Double]) -> some View {
        switch style {
        case .island:
            // Rings in the side margins beside the island.
            HStack {
                VStack(spacing: FitchiTheme.Spacing.m) {
                    StatRing(.hunger, value: values[.hunger] ?? 0)
                    StatRing(.happiness, value: values[.happiness] ?? 0)
                }
                Spacer()
                VStack(spacing: FitchiTheme.Spacing.m) {
                    StatRing(.energy, value: values[.energy] ?? 0)
                    StatRing(.cleanliness, value: values[.cleanliness] ?? 0)
                }
            }
            .offset(y: -34)
            .frame(height: 0)
        case .fullScene:
            HStack(spacing: FitchiTheme.Spacing.m) {
                ForEach(Stat.allCases, id: \.self) { StatRing($0, value: values[$0] ?? 0) }
            }
            .padding(.bottom, FitchiTheme.Spacing.xs)
        case .horizon:
            HStack(spacing: FitchiTheme.Spacing.s) {
                ForEach(Stat.allCases, id: \.self) { StatPip($0, value: values[$0] ?? 0) }
            }
            .padding(.horizontal, FitchiTheme.Spacing.s)
            .padding(.bottom, FitchiTheme.Spacing.s)
        }
    }

    /// The pet found something: a bobbing present under the header. Tap to collect it.
    private func giftButton(_ moment: PetMoment) -> some View {
        Button {
            if let collected = pets.collectGift() {
                event = CareEvent(gift: collected, petName: pet.name)
            }
        } label: {
            GiftBubble(isLucky: moment.isLucky)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 14)
        .transition(.scale.combined(with: .opacity))
        .accessibilityHint("Collects what \(pet.name) found")
    }

    private func careButtons(balance: Int) -> some View {
        HStack(spacing: FitchiTheme.Spacing.s) {
            ForEach([CareAction.feed, .play, .wash, .rest], id: \.self) { action in
                careButton(action, balance: balance)
            }
        }
    }

    private func careButton(_ action: CareAction, balance: Int) -> some View {
        let item = pets.careItem(action, for: pet, earnings: activity.earnings)
        let owned = item.map { pets.inventory.count(of: $0.id) > 0 } ?? false
        let affordable = owned || (item?.price ?? .max) <= balance
        return Button {
            care(action)
        } label: {
            Text(action.emoji)
                .font(.system(size: 17))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color(white: 0.2).opacity(0.9)))
                .overlay(alignment: .bottom) {
                    if let item, !owned {
                        Text("\(item.price)")
                            .font(FitchiTheme.Fonts.display(size: 10, weight: .bold).monospacedDigit())
                            .foregroundStyle(affordable ? FitchiTheme.Colors.points : .secondary)
                            .padding(.horizontal, 4)
                            .background(Capsule().fill(.black))
                            .offset(y: 6)
                    }
                }
                .opacity(affordable ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(action.title)\(item.map { owned ? ", owned" : ", \($0.price) Pep" } ?? "")")
    }

    private func care(_ action: CareAction) {
        do {
            let outcome = try pets.care(action, for: pet.id, earnings: activity.earnings)
            event = CareEvent(
                action: action, outcome: outcome, petName: pet.name,
                itemName: pets.catalog.item(id: outcome.itemID)?.name)
        } catch {
            event = CareEvent(action: action, failure: error, petName: pet.name)
        }
    }
}

/// What to show and feel after a care tap.
private struct CareEvent: Equatable {
    let id = UUID()
    let message: String
    let feedback: SensoryFeedback
    /// Only successful taps make the pet react.
    let reaction: StageReaction?

    init(action: CareAction, outcome: CareOutcome, petName: String, itemName: String?) {
        let gain = Int((outcome.changes[action.stat] ?? 0).rounded())
        reaction = StageReaction(id: id, action: action, floater: "\(action.emoji) +\(gain)")
        let thing = itemName.map { "the \($0.lowercased())" } ?? "that"
        switch outcome.reaction {
        case .loved:
            message = "\(petName) loves \(thing)! 💕"
            feedback = .success
        case .enjoyed:
            message = "\(petName) enjoyed \(thing)!"
            feedback = .impact(weight: .medium)
        case .meh:
            message = action == .feed ? "Picky… \(petName) only nibbled it." : "\(petName) wasn't that into it."
            feedback = .impact(weight: .light)
        case .unwell:
            message = "\(petName) feels a little better."
            feedback = .impact(weight: .light)
        }
    }

    init(gift: PetMoment, petName: String) {
        reaction = StageReaction(id: id, action: nil, floater: "\(gift.isLucky ? "🪙" : "🎁") +\(gift.pep)")
        message = gift.isLucky ? "Lucky! \(petName) found \(gift.find)! 🪙" : "\(petName) found \(gift.find)! 🎁"
        feedback = .success
    }

    init(action: CareAction, failure: QuickCareError, petName: String) {
        reaction = nil
        feedback = .error
        switch failure {
        case .alreadySatisfied(.hunger): message = "\(petName) is already full!"
        case .alreadySatisfied(.happiness): message = "\(petName) is already having a blast!"
        case .alreadySatisfied(.cleanliness): message = "\(petName) is already squeaky clean!"
        case .alreadySatisfied(.energy): message = "\(petName) isn't sleepy."
        case .cantAfford(let price): message = "Need \(price) Pep. Time for a walk!"
        case .noItem, .care: message = "\(petName) can't do that right now."
        }
    }

    static func == (lhs: CareEvent, rhs: CareEvent) -> Bool { lhs.id == rhs.id }
}
