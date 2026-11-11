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
                        .navigationTitle(pet.name)
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
            if let progress = pets.hatchProgress(samples: activity.samples) {
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
                    Text("🥚")
                        .font(.system(size: 52))
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
                    Text("Move \(progress.minutesRemaining) more min to hatch")
                        .font(FitchiTheme.Fonts.display(.headline))
                        .multilineTextAlignment(.center)
                    let fallback = progress.fallbackDate.formatted(.dateTime.weekday(.abbreviated).hour().minute())
                    Text("A brisk walk counts. Otherwise it hatches by \(fallback).")
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
        if let pet = try? pets.hatchStarter(samples: activity.samples, force: force) {
            onHatch(pet)
        }
    }
}

/// The loot-box moment: the egg shakes, cracks, and the pet appears. Then pick a name.
struct HatchRevealView: View {
    @Environment(PetStore.self) private var pets
    @Environment(\.dismiss) private var dismiss
    let pet: Pet
    @State private var revealed = false
    @State private var name: String

    init(pet: Pet) {
        self.pet = pet
        _name = State(initialValue: pet.name)
    }

    var body: some View {
        let species = pets.species(of: pet)
        ScrollView {
            VStack(spacing: FitchiTheme.Spacing.m) {
                if revealed {
                    Text(species?.emoji ?? "🐾")
                        .font(.system(size: 60))
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                    Text("It's a \(species?.name ?? "pet")!")
                        .font(FitchiTheme.Fonts.display(size: 22))
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
                } else {
                    Text("🥚")
                        .font(.system(size: 60))
                        .phaseAnimator([-14.0, 14.0]) { egg, angle in
                            egg.rotationEffect(.degrees(angle), anchor: .bottom)
                        } animation: { _ in
                            .easeInOut(duration: 0.08)
                        }
                    Text("Hatching…")
                        .font(FitchiTheme.Fonts.display(.title3))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .sensoryFeedback(.success, trigger: revealed)
        .task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.spring(duration: 0.6, bounce: 0.55)) { revealed = true }
        }
    }
}

/// Species, personality, traits and renaming.
struct PetDetailView: View {
    @Environment(PetStore.self) private var pets
    let petID: UUID
    @State private var name = ""

    var body: some View {
        if let pet = pets.roster[petID] {
            List {
                Section("Name") {
                    TextField("Name", text: $name)
                        .onSubmit { pets.rename(pet.id, to: name) }
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
