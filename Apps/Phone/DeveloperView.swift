#if DEBUG
    import FitchiCore
    import FitchiData
    import FitchiHealth
    import FitchiUI
    import SwiftUI

    /// Debug builds only: test Pep (a ledger adjustment that syncs to the watch and can be taken
    /// back) and a dress-up sandbox for trying any pet, colouring, accessory and backdrop without
    /// buying anything.
    struct DeveloperView: View {
        @Environment(PetStore.self) private var pets
        @Environment(ActivityStore.self) private var activity
        @Environment(\.dismiss) private var dismiss

        @State private var speciesID = "axolotl"
        @State private var colouring = ""
        @State private var outfit: [AccessorySlot: String] = [:]
        @State private var backdrop = SceneBackdrop.Kind.meadow
        @State private var mood = SandboxMood.content
        /// A fixed id so the sandbox pet keeps the same wandering pattern while you change it.
        @State private var sandboxID = UUID()

        var body: some View {
            NavigationStack {
                Form {
                    pep
                    sandbox
                }
                .navigationTitle("Developer")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
        }

        // MARK: - Test Pep

        private var pep: some View {
            Section {
                LabeledContent("Balance", value: "✦ \(pets.wallet(earnings: activity.earnings).balance)")
                LabeledContent("Test Pep in it", value: "✦ \(pets.testPep)")
                HStack {
                    ForEach([500, 2_000, 10_000], id: \.self) { amount in
                        Button("+\(amount.formatted())") { pets.grantTestPep(amount) }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                    }
                }
                Button("Remove test Pep", role: .destructive) { pets.removeTestPep(earnings: activity.earnings) }
                    .disabled(pets.testPep <= 0)
                HStack {
                    ForEach(["sparkle-egg", "golden-egg"], id: \.self) { egg in
                        Button("+ \(EggName.display(egg))") { pets.grantTestRewardEgg(egg) }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                    }
                }
            } header: {
                Text("Test Pep")
            } footer: {
                Text(
                    "Syncs to your watch like real Pep. Removing takes back what's left of it; "
                        + "anything bought with it stays bought. Test eggs appear on Home, ready to hatch like a streak reward."
                )
            }
        }

        // MARK: - Dress-up sandbox

        private var sandbox: some View {
            let species = pets.catalog.species(id: speciesID)
            return Section {
                if let species {
                    PetStage(
                        pet: sandboxPet(species), species: species, mood: mood.mood, backdrop: backdrop,
                        style: .fullScene, petScale: 0.36, controlsBelow: false
                    )
                    .frame(height: 260)
                    .clipShape(.rect(cornerRadius: 16))
                    .listRowInsets(EdgeInsets())
                }
                Picker("Pet", selection: $speciesID) {
                    ForEach(pets.catalog.species.filter { PetFigure.hasArt(for: $0.id) }) { species in
                        Text(species.name).tag(species.id)
                    }
                }
                .onChange(of: speciesID) { colouring = "" }
                if let species {
                    Picker("Colouring", selection: $colouring) {
                        ForEach(species.variants) { variant in
                            Text(variant.name).tag(variant.id)
                        }
                        if let shiny = species.shiny {
                            Text("✨ \(shiny.name)").tag("shiny:\(shiny.id)")
                        }
                    }
                }
                ForEach(AccessorySlot.allCases, id: \.self) { slot in
                    Picker(slot.rawValue.capitalized, selection: wearing(slot)) {
                        Text("None").tag(String?.none)
                        ForEach(pets.catalog.items.filter { $0.slot == slot }) { item in
                            Text(item.name).tag(String?.some(item.id))
                        }
                    }
                }
                Picker("Backdrop", selection: $backdrop) {
                    ForEach(SceneBackdrop.Kind.allCases, id: \.self) { kind in
                        Text(kind.rawValue.replacingOccurrences(of: "backdrop-", with: "").capitalized).tag(kind)
                    }
                }
                Picker("Mood", selection: $mood) {
                    ForEach(SandboxMood.allCases, id: \.self) { mood in
                        Text(mood.rawValue.capitalized).tag(mood)
                    }
                }
            } header: {
                Text("Dress-up sandbox")
            } footer: {
                Text("Just a preview: nothing here is bought, saved or sent to your watch.")
            }
        }

        private func wearing(_ slot: AccessorySlot) -> Binding<String?> {
            Binding(get: { outfit[slot] }, set: { outfit[slot] = $0 })
        }

        private func sandboxPet(_ species: Species) -> Pet {
            let shiny = colouring.hasPrefix("shiny:")
            let variantID = shiny ? String(colouring.dropFirst("shiny:".count)) : colouring
            var pet = Pet(
                id: sandboxID, name: "Sandbox", speciesID: species.id,
                traits: PetTraits(appetite: 1, playfulness: 1, stamina: 1, tidiness: 1), personality: .easygoing,
                hatchedAt: .now, variant: variantID.isEmpty ? nil : PetVariant(id: variantID, isShiny: shiny))
            pet.equipped = outfit
            return pet
        }
    }

    /// Moods worth eyeballing accessories in: they change the face, posture and naps.
    enum SandboxMood: String, CaseIterable {
        case content, thriving, hungry, sleepy, sad

        var mood: PetMood {
            var mood = PetMood.content
            switch self {
            case .content: break
            case .thriving: mood = PetMood(condition: .thriving)
            case .hungry: mood.isHungry = true
            case .sleepy: mood.isTired = true
            case .sad: mood = PetMood(condition: .sad)
            }
            return mood
        }
    }
#endif
