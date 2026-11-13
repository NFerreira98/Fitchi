import FitchiCore
import FitchiData
import FitchiUI
import SwiftUI

/// The mystery-egg moment on the big screen: the egg rocks, cracks three times and bursts, the
/// pet pops out (with a sparkle burst for shinies), then you name it and choose whether it goes
/// to your watch.
struct PhoneHatchView: View {
    @Environment(PetStore.self) private var pets
    @Environment(\.petHome) private var home
    @Environment(\.dismiss) private var dismiss
    let pet: Pet
    /// First time this species-and-colour has been found: it's new in the collection.
    let isNewFind: Bool
    /// Pep paid back because this colouring was already in the collection.
    let refund: Int
    @State private var stage = Stage.rocking
    @State private var flash = false
    @State private var name: String

    enum Stage: Comparable {
        case rocking
        case cracking(Int)
        case revealed
    }

    init(pet: Pet, isNewFind: Bool, refund: Int = 0) {
        self.pet = pet
        self.isNewFind = isNewFind
        self.refund = refund
        _name = State(initialValue: pet.name)
    }

    var body: some View {
        let species = pets.species(of: pet)
        VStack(spacing: FitchiTheme.Spacing.l) {
            Spacer()
            ZStack {
                if stage == .revealed {
                    if pet.isShiny { ShinyBurst().scaleEffect(2) }
                    LivingPetView(species: species, speciesID: pet.speciesID, variant: pet.variant, seed: pet.id)
                        .frame(width: 220, height: 220)
                        .transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
                } else {
                    EggFigure(crack: crackAmount)
                        .frame(width: 180, height: 180)
                        .phaseAnimator([-1.0, 1.0]) { egg, side in
                            egg.rotationEffect(.degrees(side * rockAngle), anchor: .bottom)
                        } animation: { _ in
                            .easeInOut(duration: rockSpeed)
                        }
                }
                Circle()
                    .fill(.white)
                    .frame(width: 120, height: 120)
                    .scaleEffect(flash ? 6 : 0.1)
                    .opacity(flash ? 0 : (stage == .revealed ? 0 : 0.0001))
                    .allowsHitTesting(false)
            }
            .frame(height: 240)

            if stage == .revealed {
                details(species: species)
                    .transition(.opacity)
            } else {
                Text("Hatching…")
                    .font(FitchiTheme.Fonts.display(.title))
            }
            Spacer()
        }
        .padding(FitchiTheme.Spacing.l * 1.5)
        .sensoryFeedback(trigger: stage) { _, new in
            switch new {
            case .rocking: nil
            case .cracking: .impact(weight: .medium)
            case .revealed: pet.isShiny ? .levelChange : .success
            }
        }
        .task { await play() }
    }

    @ViewBuilder
    private func details(species: Species?) -> some View {
        let colouring = species?.colorVariant(for: pet.variant)
        VStack(spacing: FitchiTheme.Spacing.s) {
            if pet.isShiny {
                Text("✨ A shiny! ✨")
                    .font(FitchiTheme.Fonts.display(size: 30))
                    .foregroundStyle(CollectionCard.gold)
            }
            Text(isNewFind || pet.isShiny ? "It's a \(species?.name ?? "pet")!" : "Another \(species?.name ?? "pet")!")
                .font(FitchiTheme.Fonts.display(size: 34))
            HStack(spacing: FitchiTheme.Spacing.s) {
                if let colouring { Text(colouring.name) }
                if let rarity = species?.rarity {
                    Text(rarity.title).foregroundStyle(rarity.color)
                }
                if isNewFind {
                    Text("NEW in your collection")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(FitchiTheme.Colors.accent.opacity(0.2), in: .capsule)
                        .foregroundStyle(FitchiTheme.Colors.accent)
                }
            }
            .font(FitchiTheme.Fonts.text(.subheadline, weight: .semibold))
            .foregroundStyle(.secondary)
            if let condition = colouring?.when {
                // A special colouring: say what made it possible.
                Text("\(condition.emoji) \(condition.hint)!")
                    .font(FitchiTheme.Fonts.text(.subheadline, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.indigo.opacity(0.18), in: .capsule)
                    .foregroundStyle(.indigo)
            }
            if !isNewFind {
                // A repeat is still its own pet: say what makes this one different.
                Text("\(pet.personality.title) · \(pet.personality.blurb)")
                    .font(FitchiTheme.Fonts.text(.footnote))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if refund > 0 {
                    Text("+\(refund) Pep back for a repeat")
                        .font(FitchiTheme.Fonts.display(.headline).monospacedDigit())
                        .foregroundStyle(FitchiTheme.Colors.points)
                }
            }
        }
        .multilineTextAlignment(.center)

        nameField
        actions
    }

    private var nameField: some View {
        HStack {
            TextField("Name", text: $name)
                .font(FitchiTheme.Fonts.display(.title3))
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
            Button {
                name = pets.suggestedName(for: pet, excluding: name)
            } label: {
                Image(systemName: "shuffle")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Another name")
        }
    }

    private var actions: some View {
        VStack(spacing: FitchiTheme.Spacing.s) {
            if pet.isActive {
                // The starter pet: it's already the one you look after.
                Button {
                    finish(sendToWatch: false)
                } label: {
                    Text("Say hello").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    finish(sendToWatch: true)
                } label: {
                    Text(home == .watch ? "Send to my watch" : "Make it my active pet").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    finish(sendToWatch: false)
                } label: {
                    Text("Keep it resting for now").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .font(FitchiTheme.Fonts.display(.headline))
        .tint(FitchiTheme.Colors.accent)
    }

    private func finish(sendToWatch: Bool) {
        pets.rename(pet.id, to: name)
        if sendToWatch { pets.setActive(pet.id) }
        dismiss()
    }

    private var crackAmount: Double {
        if case .cracking(let count) = stage { return Double(count) / 3 }
        return 0
    }

    /// The egg rocks harder and faster with every crack.
    private var rockAngle: Double {
        if case .cracking(let count) = stage { return 6 + Double(count) * 4 }
        return 5
    }

    private var rockSpeed: Double {
        if case .cracking(let count) = stage { return 0.22 - Double(count) * 0.05 }
        return 0.45
    }

    private func play() async {
        guard stage == .rocking else { return }
        try? await Task.sleep(for: .seconds(1.2))
        for count in 1...3 {
            stage = .cracking(count)
            try? await Task.sleep(for: .seconds(0.75))
        }
        withAnimation(.easeOut(duration: 0.5)) { flash = true }
        try? await Task.sleep(for: .seconds(0.12))
        withAnimation(.spring(duration: 0.6, bounce: 0.55)) { stage = .revealed }
    }
}
