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

    /// The light the whole app is coloured by (light or dark, the tinted pages), in 10-minute
    /// steps so it only changes when the world visibly does.
    @State private var light = Self.light(at: .now)

    var body: some View {
        tabs
            .preferredColorScheme(light.night > 0.5 ? .dark : .light)
            .environment(
                \.worldTint, WorldTint(backdrop: SceneBackdrop.Kind(id: pets.inventory.activeBackdropID), light: light)
            )
            // Checked once a minute, but only a real change touches the view tree. Don't drive
            // this from a TimelineView: re-applying the colour scheme on every tick re-renders the
            // tabs, and with another minute timeline inside a List (the shop's hatch banner) the
            // two invalidate each other forever and the app freezes.
            .task {
                while !Task.isCancelled {
                    let now = Self.light(at: .now)
                    if now != light { light = now }
                    try? await Task.sleep(for: .seconds(60))
                }
            }
    }

    private static func light(at date: Date) -> SceneLight {
        let step: TimeInterval = 600
        let rounded = Date(
            timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / step).rounded(.down) * step)
        return SceneLight.now(rounded)
    }

    private var tabs: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house.fill", value: "home") {
                PhoneHomeView(showAllPets: { tab = "pets" })
            }
            Tab("Pets", systemImage: "pawprint.fill", value: "pets") {
                PetsView()
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
    @Environment(\.petHome) private var home
    @AppStorage(CareReminders.enabledKey) private var remindersOn = true
    @State private var showsDeveloper = false
    @State private var showsGuide = false
    /// The starter pet that just hatched on this iPhone, for the reveal.
    @State private var newborn: Pet?
    /// Opens the Pets tab.
    var showAllPets: () -> Void = {}

    var body: some View {
        GeometryReader { geometry in
            // The tint comes from `PhoneRootView`, shared with every tab.
            page(topInset: geometry.safeAreaInsets.top)
                .worldPage()
                // With a pet, its world runs up under the status bar.
                .ignoresSafeArea(edges: pets.activePet == nil ? [] : .top)
        }
        .fullScreenCover(item: $newborn) {
            CareReminders.holdsPermissionPrompt = false
            PetCompanions.refresh(pets, sendsReminders: home == .phone)
        } content: { pet in
            PhoneHatchView(pet: pet, isNewFind: true)
        }
        .sheet(isPresented: $showsGuide) { WelcomeView(isFirstRun: false) { showsGuide = false } }
        #if DEBUG
            .sheet(isPresented: $showsDeveloper) { DeveloperView() }
        #endif
    }

    private func page(topInset: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: FitchiTheme.Spacing.l * 2) {
                if let pet = pets.activePet {
                    PhonePetView(pet: pet, topInset: topInset)
                    PhoneQuestsCard(petName: pet.name).padding(.horizontal, FitchiTheme.Spacing.l)
                    if pets.roster.pets.count > 1 {
                        PetRosterView(showAll: showAllPets).padding(.horizontal, FitchiTheme.Spacing.l)
                    }
                } else if pets.pendingEgg != nil {
                    PhoneEggView { newborn = $0 }.padding(.horizontal, FitchiTheme.Spacing.l)
                } else if home == .phone {
                    ProgressView()
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
                    .worldCard(cornerRadius: 20)
                    .padding(.horizontal, FitchiTheme.Spacing.l)
                if home == .phone {
                    // Without a watch, the iPhone sends the "hungry" and gift notifications.
                    Toggle("Care reminders", systemImage: "bell.fill", isOn: $remindersOn)
                        .font(FitchiTheme.Fonts.text(.subheadline, weight: .semibold))
                        .padding(FitchiTheme.Spacing.m)
                        .worldCard(cornerRadius: 16)
                        .padding(.horizontal, FitchiTheme.Spacing.l)
                        .onChange(of: remindersOn) { PetCompanions.refresh(pets, sendsReminders: true) }
                }
                Button("How Fitchi works", systemImage: "questionmark.circle") { showsGuide = true }
                    .font(FitchiTheme.Fonts.text(.footnote, weight: .semibold))
                    .foregroundStyle(.secondary)
                #if DEBUG
                    Button("Developer tools", systemImage: "hammer.fill") { showsDeveloper = true }
                        .font(FitchiTheme.Fonts.text(.footnote, weight: .semibold))
                        .foregroundStyle(.secondary)
                #endif
            }
            .padding(.top, pets.activePet == nil ? FitchiTheme.Spacing.l : 0)
            .padding(.bottom, FitchiTheme.Spacing.l)
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

/// Every pet you own. One is active; the rest rest (and get hungry more slowly).
struct PetRosterView: View {
    @Environment(PetStore.self) private var pets
    @Environment(\.petHome) private var home
    var showAll: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: FitchiTheme.Spacing.s) {
            HStack {
                Text("Your pets").font(FitchiTheme.Fonts.display(.headline))
                Spacer()
                Button("See all \(pets.roster.pets.count)", action: showAll)
                    .font(FitchiTheme.Fonts.text(.subheadline, weight: .semibold))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: FitchiTheme.Spacing.m) {
                    // Favourites first, then the newest.
                    ForEach(Array(RosterQuery().apply(to: pets.roster.pets, in: pets.catalog).prefix(12))) { pet in
                        card(pet)
                    }
                }
            }
        }
    }

    private func card(_ pet: Pet) -> some View {
        VStack(spacing: 4) {
            LivingPetView(
                species: pets.species(of: pet), speciesID: pet.speciesID, variant: pet.variant, seed: pet.id,
                accessories: pet.equipped, personality: pet.personality, framesPerSecond: 15
            )
            .frame(width: 72, height: 72)
            Text(pet.name).font(FitchiTheme.Fonts.display(.subheadline)).lineLimit(1)
            if pet.isActive {
                Label(home.activeShort, systemImage: home.symbol)
                    .font(FitchiTheme.Fonts.text(.caption2, weight: .semibold))
                    .foregroundStyle(.green)
            } else {
                Button(home.makeActive) { pets.setActive(pet.id) }
                    .font(FitchiTheme.Fonts.text(.caption2, weight: .semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
            }
        }
        .frame(width: 104)
        .padding(.vertical, FitchiTheme.Spacing.s)
        .worldCard(cornerRadius: 16)
    }
}

#Preview {
    let pets = PetStore.makeDefault(grantsStarterEgg: false)
    PhoneRootView()
        .environment(ActivityStore.preview())
        .environment(pets)
        .environment(BackupLink(pets: pets, installDate: { nil }, adoptInstallDate: { _ in }))
}
