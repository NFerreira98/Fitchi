import FitchiCore
import FitchiData
import FitchiHealth
import FitchiUI
import SwiftUI

/// The first page: the egg until it hatches, then the pet. Owns the hatch reveal so it stays
/// on screen while the page underneath switches from egg to pet.
struct PetHomeView: View {
    @Environment(PetStore.self) private var pets
    @State private var newborn: Pet?

    var body: some View {
        Group {
            switch pets.status {
            case .loading:
                ProgressView()
            case .failed(let message):
                Text(message)
                    .multilineTextAlignment(.center)
                    .font(.footnote)
            case .ready:
                if let pet = pets.activePet {
                    PetView(pet: pet)
                } else {
                    EggView { newborn = $0 }
                        .navigationTitle("Your egg")
                }
            }
        }
        .fullScreenCover(item: $newborn) { pet in
            HatchRevealView(pet: pet)
        }
        #if targetEnvironment(simulator)
            // `xcrun simctl launch … -autoHatch` skips the tap, for screenshots and UI checks.
            .task {
                guard ProcessInfo.processInfo.arguments.contains("-autoHatch") else { return }
                try? await Task.sleep(for: .seconds(2))
                if let pet = try? pets.hatchStarter(samples: [], force: true) { newborn = pet }
            }
        #endif
    }
}

/// The starter egg with a ring that fills as you move.
struct EggView: View {
    @Environment(PetStore.self) private var pets
    @Environment(ActivityStore.self) private var activity
    let onHatch: (Pet) -> Void

    var body: some View {
        // Re-check every minute so the overnight fallback flips to "ready" on its own.
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            if let progress = pets.hatchProgress(samples: activity.samples, steps: activity.steps) {
                content(progress)
            }
        }
    }

    private func content(_ progress: HatchProgress) -> some View {
        ScrollView {
            VStack(spacing: FitchiTheme.Spacing.m) {
                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progress.fraction)
                        .stroke(FitchiTheme.Colors.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut, value: progress.fraction)
                    // The crack creeps across the egg as you move.
                    EggFigure(crack: progress.isReady ? 1 : progress.fraction * 0.7)
                        .frame(width: 70, height: 70)
                        .phaseAnimator([-7.0, 7.0]) { egg, angle in
                            egg.rotationEffect(.degrees(angle), anchor: .bottom)
                        } animation: { _ in
                            .easeInOut(duration: progress.isReady ? 0.12 : 0.9)
                        }
                }
                .frame(width: 96, height: 96)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Egg, \(Int(progress.fraction * 100)) percent ready")

                if progress.isReady {
                    Text("Something's moving!")
                        .font(FitchiTheme.Fonts.display(.headline))
                    Button("Hatch!") { hatch(force: false) }
                        .font(FitchiTheme.Fonts.display(.headline))
                        .tint(FitchiTheme.Colors.accent)
                } else {
                    Text("About \(progress.stepsRemaining) more steps to hatch")
                        .font(FitchiTheme.Fonts.display(.headline))
                        .multilineTextAlignment(.center)
                    let fallback = progress.fallbackDate.formatted(.dateTime.weekday(.abbreviated).hour().minute())
                    Text("Any walking counts, a workout counts faster. Otherwise it hatches by \(fallback).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                #if targetEnvironment(simulator)
                    Button("Hatch now (simulator)") { hatch(force: true) }
                        .font(.caption2)
                #endif
            }
        }
    }

    private func hatch(force: Bool) {
        if let pet = try? pets.hatchStarter(samples: activity.samples, steps: activity.steps, force: force) {
            onHatch(pet)
        }
    }
}

/// The mystery-egg moment: the egg rocks, cracks three times, bursts in a flash and the pet
/// pops out. Shinies get a sparkle burst and their own fanfare. Then pick a name.
struct HatchRevealView: View {
    @Environment(PetStore.self) private var pets
    @Environment(\.dismiss) private var dismiss
    let pet: Pet
    @State private var stage = Stage.rocking
    @State private var flash = false
    @State private var name: String

    enum Stage: Comparable {
        case rocking
        case cracking(Int)
        case revealed
    }

    init(pet: Pet) {
        self.pet = pet
        _name = State(initialValue: pet.name)
    }

    var body: some View {
        let species = pets.species(of: pet)
        ScrollView {
            VStack(spacing: FitchiTheme.Spacing.s) {
                ZStack {
                    if stage == .revealed {
                        if pet.isShiny { ShinyBurst() }
                        LivingPetView(species: species, speciesID: pet.speciesID, variant: pet.variant, seed: pet.id)
                            .frame(width: 110, height: 110)
                            .transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
                    } else {
                        EggFigure(crack: crackAmount)
                            .frame(width: 90, height: 90)
                            .phaseAnimator([-1.0, 1.0]) { egg, side in
                                egg.rotationEffect(.degrees(side * rockAngle), anchor: .bottom)
                            } animation: { _ in
                                .easeInOut(duration: rockSpeed)
                            }
                    }
                    Circle()
                        .fill(.white)
                        .frame(width: 60, height: 60)
                        .scaleEffect(flash ? 4 : 0.1)
                        .opacity(flash ? 0 : (stage == .revealed ? 0 : 0.0001))
                        .allowsHitTesting(false)
                }
                .frame(height: 115)

                if stage == .revealed {
                    revealedDetails(species: species)
                } else {
                    Text("Hatching…")
                        .font(FitchiTheme.Fonts.display(.title3))
                }
            }
            .frame(maxWidth: .infinity)
        }
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
    private func revealedDetails(species: Species?) -> some View {
        let colouring = species?.colorVariant(for: pet.variant)
        if pet.isShiny {
            Text("✨ A shiny! ✨")
                .font(FitchiTheme.Fonts.display(size: 22))
                .foregroundStyle(FitchiTheme.Colors.points)
        }
        Text("It's a \(species?.name ?? "pet")!")
            .font(FitchiTheme.Fonts.display(size: pet.isShiny ? 18 : 22))
        if let colouring {
            Text(colouring.name)
                .font(FitchiTheme.Fonts.text(.footnote, weight: .semibold))
                .foregroundStyle(pet.isShiny ? FitchiTheme.Colors.points : .secondary)
        }
        TextField("Name", text: $name)
            .multilineTextAlignment(.center)
        Button {
            name = pets.suggestedName(for: pet, excluding: name)
        } label: {
            Label("Another name", systemImage: "shuffle")
        }
        Button("Done") {
            pets.rename(pet.id, to: name)
            dismiss()
        }
        .font(FitchiTheme.Fonts.display(.headline))
        .tint(FitchiTheme.Colors.accent)
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

/// Species, personality, traits and renaming.
struct PetDetailView: View {
    @Environment(PetStore.self) private var pets
    let petID: UUID
    @State private var name = ""
    @AppStorage(PetLayoutStyle.storageKey) private var style = PetLayoutStyle.island
    @AppStorage(CareReminders.enabledKey) private var remindersOn = true

    var body: some View {
        if let pet = pets.roster[petID] {
            List {
                Section("Name") {
                    TextField("Name", text: $name)
                        .onSubmit { pets.rename(pet.id, to: name) }
                }
                Section {
                    Picker("Pet screen", selection: $style) {
                        ForEach(PetLayoutStyle.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } header: {
                    Text("Display")
                } footer: {
                    Text(style.summary)
                }
                Section {
                    Toggle("Care reminders", isOn: $remindersOn)
                        .onChange(of: remindersOn) { PetCompanions.refresh(pets) }
                } footer: {
                    Text("A nudge when \(pet.name) gets hungry, bored, sleepy or grubby. Never at night.")
                }
                Section("Personality") {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pet.personality.title).font(FitchiTheme.Fonts.display(.headline))
                        Text(pet.personality.blurb).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Section("Traits") {
                    trait("Appetite", pet.traits.appetite)
                    trait("Playfulness", pet.traits.playfulness)
                    trait("Stamina", pet.traits.stamina)
                    trait("Tidiness", pet.traits.tidiness)
                }
                Section {
                    LabeledContent("Species", value: pets.species(of: pet)?.name ?? pet.speciesID)
                    if let colouring = pets.species(of: pet)?.colorVariant(for: pet.variant) {
                        LabeledContent("Colour", value: pet.isShiny ? "✨ \(colouring.name)" : colouring.name)
                    }
                    LabeledContent("Hatched", value: pet.hatchedAt.formatted(date: .abbreviated, time: .omitted))
                }
            }
            .navigationTitle(pet.name)
            .onAppear { name = pet.name }
        }
    }

    private func trait(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2)
            ProgressView(value: value)
                .tint(FitchiTheme.Colors.accent)
        }
    }
}
