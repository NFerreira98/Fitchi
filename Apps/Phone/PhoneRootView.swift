import FitchiCore
import FitchiData
import FitchiHealth
import FitchiUI
import SwiftUI

/// Phone tab shell: your pet, the shop, the collection book and achievements.
struct PhoneRootView: View {
    @Environment(PetStore.self) private var pets
    /// In the simulator, `-startTab shop` (etc.) at launch opens that tab, for screenshots.
    @State private var tab =
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil
        ? "home" : (UserDefaults.standard.string(forKey: "startTab") ?? "home")

    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house.fill", value: "home") {
                PhoneHomeView()
            }
            Tab("Shop", systemImage: "bag.fill", value: "shop") {
                ShopView()
            }
            Tab("Collection", systemImage: "square.grid.3x3.fill", value: "collection") {
                CollectionView()
            }
            Tab("Achievements", systemImage: "trophy.fill", value: "achievements") {
                AchievementsView()
            }
        }
        .tint(FitchiTheme.Colors.accent)
        .overlay(alignment: .top) {
            if let next = pets.celebrations.first {
                AchievementCelebration(next)
                    .padding(.top, 8)
                    .id(next.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { pets.dismissCelebration() }
                    .task(id: next.id) {
                        try? await Task.sleep(for: .seconds(3.5))
                        pets.dismissCelebration()
                    }
            }
        }
        .overlay(alignment: .top) {
            if pets.celebrations.isEmpty, let notice = pets.questNotices.first {
                QuestNoticeCard(notice, petName: pets.activePet?.name ?? "your pet")
                    .padding(.top, 8)
                    .id(notice.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { pets.dismissQuestNotice() }
                    .task(id: notice.id) {
                        try? await Task.sleep(for: .seconds(3))
                        pets.dismissQuestNotice()
                    }
            }
        }
        .animation(.spring(duration: 0.5), value: pets.questNotices.first?.id)
        .animation(.spring(duration: 0.5), value: pets.celebrations.first?.id)
        .sensoryFeedback(.success, trigger: pets.celebrations.first?.id) { _, new in new != nil }
    }
}

struct PhoneHomeView: View {
    @Environment(ActivityStore.self) private var activity
    @Environment(PetStore.self) private var pets
    @Environment(BackupLink.self) private var backup
    @State private var showsDeveloper = false

    var body: some View {
        ScrollView {
            VStack(spacing: FitchiTheme.Spacing.l * 2) {
                if let pet = pets.activePet {
                    BackedUpPetView(pet: pet, lastBackup: backup.lastExchange)
                    PhoneQuestsCard(petName: pet.name)
                    if pets.roster.pets.count > 1 { PetRosterView() }
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
                #if DEBUG
                    Button("Developer tools", systemImage: "hammer.fill") { showsDeveloper = true }
                        .font(FitchiTheme.Fonts.text(.footnote, weight: .semibold))
                        .foregroundStyle(.secondary)
                #endif
            }
            .padding(FitchiTheme.Spacing.l)
        }
        .refreshable { await activity.refresh() }
        #if DEBUG
            .sheet(isPresented: $showsDeveloper) { DeveloperView() }
        #endif
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
                PetStage(
                    pet: pet, species: pets.species(of: pet), mood: mood,
                    backdrop: SceneBackdrop.Kind(id: pets.inventory.activeBackdropID), style: .fullScene,
                    petScale: 0.36,
                    controlsBelow: false
                )
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

/// Every pet you own. One lives on your watch; the rest rest (and get hungry more slowly).
struct PetRosterView: View {
    @Environment(PetStore.self) private var pets

    var body: some View {
        VStack(alignment: .leading, spacing: FitchiTheme.Spacing.s) {
            Text("Your pets").font(FitchiTheme.Fonts.display(.headline))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FitchiTheme.Spacing.m) {
                    ForEach(pets.roster.pets) { pet in
                        card(pet)
                    }
                }
            }
        }
    }

    private func card(_ pet: Pet) -> some View {
        VStack(spacing: 4) {
            LivingPetView(species: pets.species(of: pet), speciesID: pet.speciesID, variant: pet.variant, seed: pet.id)
                .frame(width: 72, height: 72)
            Text(pet.name).font(FitchiTheme.Fonts.display(.subheadline)).lineLimit(1)
            if pet.isActive {
                Label("On watch", systemImage: "applewatch")
                    .font(FitchiTheme.Fonts.text(.caption2, weight: .semibold))
                    .foregroundStyle(.green)
            } else {
                Button("Send to watch") { pets.setActive(pet.id) }
                    .font(FitchiTheme.Fonts.text(.caption2, weight: .semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
        .frame(width: 104)
        .padding(.vertical, FitchiTheme.Spacing.s)
        .background(.fill.tertiary, in: .rect(cornerRadius: 16))
    }
}

#Preview {
    let pets = PetStore.makeDefault(grantsStarterEgg: false)
    PhoneRootView()
        .environment(ActivityStore.preview())
        .environment(pets)
        .environment(BackupLink(pets: pets, installDate: { nil }, adoptInstallDate: { _ in }))
}
