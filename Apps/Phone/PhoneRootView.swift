import FitchiCore
import FitchiData
import FitchiHealth
import FitchiUI
import SwiftUI

/// Phone tab shell: hub, shop, wardrobe, achievements. Screens are filled in Milestone 6.
struct PhoneRootView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                PhoneHomeView()
            }
            Tab("Shop", systemImage: "bag.fill") {
                Text("Shop")
            }
            Tab("Achievements", systemImage: "trophy.fill") {
                Text("Achievements")
            }
        }
        .tint(FitchiTheme.Colors.accent)
    }
}

struct PhoneHomeView: View {
    @Environment(ActivityStore.self) private var activity
    @Environment(PetStore.self) private var pets
    @Environment(BackupLink.self) private var backup

    var body: some View {
        ScrollView {
            VStack(spacing: FitchiTheme.Spacing.l * 2) {
                if let pet = pets.activePet {
                    BackedUpPetView(pet: pet, lastBackup: backup.lastExchange)
                } else {
                    VStack(spacing: FitchiTheme.Spacing.s) {
                        Text("⌚️").font(.system(size: 56))
                        Text("Your pet lives on your Apple Watch")
                            .font(.headline)
                        Text("Once it hatches, it's backed up here automatically.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.top, FitchiTheme.Spacing.l * 2)
                }
                today
                    .frame(maxWidth: .infinity)
                    .padding(FitchiTheme.Spacing.l)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 20))
            }
            .padding(FitchiTheme.Spacing.l)
        }
        .refreshable { await activity.refresh() }
    }

    @ViewBuilder private var today: some View {
        switch activity.status {
        case .idle, .loading:
            ProgressView()
        case .unavailable:
            Text("Health isn't available on this device.")
        case .failed(let message):
            VStack(spacing: FitchiTheme.Spacing.s) {
                Text(message)
                Button("Try again") { Task { await activity.start() } }
            }
        case .ready:
            VStack(spacing: FitchiTheme.Spacing.m) {
                Text("Today").font(.headline)
                TodaySummaryView(
                    summary: activity.today,
                    // Earnings from Health plus the backed-up ledger (bonus and spending).
                    balance: pets.wallet(earnings: activity.earnings).balance,
                    dailyGoal: Int(activity.rules.dailySoftCap)
                )
            }
        }
    }
}

/// The pet as last backed up from the watch. The watch is where you care for it; this copy is
/// what restores it if the watch app is ever reinstalled.
struct BackedUpPetView: View {
    @Environment(PetStore.self) private var pets
    let pet: Pet
    let lastBackup: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let mood = pet.mood(at: timeline.date, in: pets.decay)
            VStack(spacing: FitchiTheme.Spacing.s) {
                PetStage(pet: pet, species: pets.species(of: pet), mood: mood, style: .fullScene, petScale: 0.45)
                    // Square-ish like the watch, so the pet stands on the meadow.
                    .aspectRatio(1.1, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 28))
                Text(pet.name)
                    .font(FitchiTheme.Fonts.display(.title))
                Text(mood.headline)
                    .font(FitchiTheme.Fonts.text(.subheadline))
                    .foregroundStyle(.secondary)
                Label(backupLine(at: timeline.date), systemImage: "checkmark.shield")
                    .font(FitchiTheme.Fonts.text(.footnote))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func backupLine(at now: Date) -> String {
        guard let lastBackup else { return "Backed up from your watch" }
        let ago = lastBackup.formatted(.relative(presentation: .named, unitsStyle: .wide))
        return now.timeIntervalSince(lastBackup) < 60
            ? "Backed up from your watch just now" : "Backed up from your watch \(ago)"
    }
}

#Preview {
    let pets = PetStore.makeDefault(grantsStarterEgg: false)
    PhoneRootView()
        .environment(ActivityStore.preview())
        .environment(pets)
        .environment(BackupLink(pets: pets, installDate: { nil }, adoptInstallDate: { _ in }))
}
