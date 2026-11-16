#if DEBUG
    import FitchiCore
    import FitchiData
    import FitchiHealth
    import SwiftUI

    /// Developer tools: pretend walks and steps (`SimulatedActivity`), to try a comeback, quests,
    /// cheers or hatching without going out. They count on this iPhone like real activity.
    struct DeveloperActivitySection: View {
        @Environment(PetStore.self) private var pets
        @Environment(ActivityStore.self) private var activity

        var body: some View {
            Section {
                LabeledContent("Added", value: added)
                if let pet = pets.activePet,
                    let comeback = pets.comebackProgress(for: pet, samples: activity.samples, steps: activity.steps)
                {
                    LabeledContent(
                        "Way home",
                        value: "\(Int(comeback.activeMinutes.rounded(.down))) of \(Int(comeback.requiredMinutes)) min")
                }
                HStack {
                    ForEach([10, 30, 60], id: \.self) { minutes in
                        Button("+\(minutes) min walk") {
                            Task { await activity.simulateWalk(minutes: Double(minutes)) }
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                }
                HStack {
                    ForEach([1_000, 5_000, 10_000], id: \.self) { steps in
                        Button("+\(steps.formatted()) steps") { Task { await activity.simulateSteps(Double(steps)) } }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                    }
                }
                Button("Remove pretend activity", role: .destructive) { Task { await activity.clearSimulated() } }
                    .disabled(activity.simulated.isEmpty)
            } header: {
                Text("Pretend activity")
            } footer: {
                Text(
                    "Counts on this iPhone like real activity: Pep, quests, cheers, eggs and bringing a pet home. "
                        + "It isn't written to Health, so your watch doesn't see it (its Pep total won't include it). "
                        + "Each one starts where the last ends, so walks and steps never overlap."
                )
            }
            .font(.footnote)
        }

        private var added: String {
            let simulated = activity.simulated
            guard !simulated.isEmpty else { return "Nothing" }
            return "\(Int(simulated.walkMinutes)) min walking, \(Int(simulated.stepTotal).formatted()) steps"
        }
    }
#endif
