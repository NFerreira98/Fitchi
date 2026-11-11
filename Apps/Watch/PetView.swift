import FitchiCore
import FitchiData
import FitchiHealth
import FitchiUI
import SwiftUI

/// The pet's live stats and the four care buttons. Stats are computed from time, so the view
/// re-reads them every minute.
struct PetView: View {
    @Environment(PetStore.self) private var pets
    @Environment(ActivityStore.self) private var activity
    let pet: Pet

    /// The latest care tap (or failed tap), driving the hop, floating emoji, message and haptic.
    @State private var event: CareEvent?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let values = pet.values(at: timeline.date, in: pets.decay)
            let balance = pets.wallet(earnings: activity.earnings).balance
            ScrollView {
                VStack(spacing: FitchiTheme.Spacing.s) {
                    Label("\(balance) Pep", systemImage: "sparkles")
                        .font(FitchiTheme.Fonts.display(.headline).monospacedDigit())
                        .foregroundStyle(FitchiTheme.Colors.points)
                        .contentTransition(.numericText(value: Double(balance)))
                        .animation(.snappy, value: balance)

                    PetAvatar(pet: pet, species: pets.species(of: pet), event: event)

                    Text(event?.message ?? pet.condition(at: timeline.date, in: pets.decay).title)
                        .font(.footnote)
                        .foregroundStyle(event == nil ? .secondary : .primary)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                        .animation(.easeInOut, value: event?.message)

                    StatBarsView(values: values)
                        .animation(.spring(duration: 0.6), value: values)
                        .padding(.vertical, FitchiTheme.Spacing.xs)

                    careButtons(balance: balance)

                    NavigationLink("About \(pet.name)") {
                        PetDetailView(petID: pet.id)
                    }
                }
            }
        }
        .sensoryFeedback(trigger: event) { _, new in new?.feedback }
        .task(id: event) {
            guard event != nil else { return }
            try? await Task.sleep(for: .seconds(2.5))
            event = nil
        }
    }

    private func careButtons(balance: Int) -> some View {
        Grid(horizontalSpacing: FitchiTheme.Spacing.s, verticalSpacing: FitchiTheme.Spacing.s) {
            GridRow {
                careButton(.feed, balance: balance)
                careButton(.play, balance: balance)
            }
            GridRow {
                careButton(.wash, balance: balance)
                careButton(.rest, balance: balance)
            }
        }
    }

    private func careButton(_ action: CareAction, balance: Int) -> some View {
        let item = pets.careItem(action, for: pet, earnings: activity.earnings)
        let owned = item.map { pets.inventory.count(of: $0.id) > 0 } ?? false
        return Button {
            care(action)
        } label: {
            VStack(spacing: 0) {
                Text(action.emoji).font(.title3)
                Text(action.title).font(FitchiTheme.Fonts.display(.footnote))
                if let item {
                    Text(owned ? "Owned" : "\(item.price) Pep")
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(owned || item.price <= balance ? FitchiTheme.Colors.points : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
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

/// The pet in its scene. It idles on its own (breathing, blinking, glancing around), hops on
/// each successful care tap, and the action's emoji and stat gain float up from it.
private struct PetAvatar: View {
    let pet: Pet
    let species: Species?
    let event: CareEvent?
    @State private var excited = false

    var body: some View {
        ZStack(alignment: .bottom) {
            SceneBackdrop(.meadow)
            LivingPetView(
                species: species, speciesID: pet.speciesID, variant: pet.variant, excited: excited, seed: pet.id
            )
            .padding(.horizontal, 28)
            .keyframeAnimator(initialValue: Hop(), trigger: event?.hopTrigger) { content, hop in
                content
                    .scaleEffect(x: hop.squash, y: 2 - hop.squash, anchor: .bottom)
                    .offset(y: hop.lift)
            } keyframes: { _ in
                KeyframeTrack(\.lift) {
                    CubicKeyframe(0, duration: 0.08)
                    SpringKeyframe(-16, duration: 0.2)
                    SpringKeyframe(0, duration: 0.35, spring: .bouncy)
                }
                KeyframeTrack(\.squash) {
                    CubicKeyframe(1.15, duration: 0.08)
                    CubicKeyframe(0.92, duration: 0.2)
                    SpringKeyframe(1, duration: 0.35, spring: .bouncy)
                }
            }
            .accessibilityHidden(true)

            if let event, let floater = event.floater {
                FloatingText(text: floater)
                    .id(event.id)
                    .padding(.bottom, 70)
            }
        }
        .frame(height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .task(id: event?.hopTrigger) {
            // Happy wiggle for a moment after a successful care tap.
            guard event?.hopTrigger != nil, event?.floater != nil else { return }
            excited = true
            try? await Task.sleep(for: .seconds(1.6))
            excited = false
        }
    }

    struct Hop {
        var lift: Double = 0
        var squash: Double = 1
    }
}

/// Rises and fades out once.
private struct FloatingText: View {
    let text: String
    @State private var risen = false

    var body: some View {
        Text(text)
            .font(FitchiTheme.Fonts.display(.headline, weight: .heavy).monospacedDigit())
            .offset(x: 30, y: risen ? -34 : -4)
            .opacity(risen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.4)) { risen = true }
            }
            .accessibilityHidden(true)
    }
}

/// What to show and feel after a care tap.
private struct CareEvent: Equatable {
    let id = UUID()
    let message: String
    let floater: String?
    let feedback: SensoryFeedback
    /// Changes only on success, so failed taps don't make the pet hop.
    let hopTrigger: UUID?

    init(action: CareAction, outcome: CareOutcome, petName: String, itemName: String?) {
        let gain = Int((outcome.changes[action.stat] ?? 0).rounded())
        floater = "\(action.emoji) +\(gain)"
        hopTrigger = id
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

    init(action: CareAction, failure: QuickCareError, petName: String) {
        floater = nil
        hopTrigger = nil
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
