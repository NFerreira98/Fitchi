import FitchiData
import FitchiHealth
import FitchiUI
import SwiftUI

@main
struct FitchiPhoneApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var activity: ActivityStore
    @State private var pets: PetStore
    @State private var backup: BackupLink
    /// The first-run guide is done (see `WelcomeView`). Health is only asked for after it.
    @AppStorage(WelcomeView.seenKey) private var welcomed = false

    init() {
        FitchiTheme.Fonts.register()
        let store = ActivityStore.makeDefault(installDate: AppInstall.date())
        // The phone only grants the starter egg once it knows there's no watch (see `phoneHome`).
        let pets = PetStore.makeDefault(grantsStarterEgg: false)
        // Players who already have a pet or an egg know the game: no guide for them.
        if !pets.roster.pets.isEmpty || pets.starterEgg != nil {
            UserDefaults.standard.set(true, forKey: WelcomeView.seenKey)
        }
        let backup = BackupLink(
            pets: pets, installDate: { AppInstall.date() },
            adoptInstallDate: { date in
                if AppInstall.adopt(date) { store.adoptInstallDate(date) }
            })
        _activity = State(initialValue: store)
        _pets = State(initialValue: pets)
        _backup = State(initialValue: backup)
        backup.start()
        // Achievements pay out whenever the game changes (and after activity refreshes, below).
        pets.onChange { Self.claimAchievements(pets, activity: store) }
        // The Home Screen widget, and (without a watch) care reminders, follow every change.
        pets.onChange { PetCompanions.refresh(pets, sendsReminders: Self.sendsReminders(backup)) }
    }

    /// Without a watch that has the app, the iPhone is the pet's home and sends reminders.
    static func sendsReminders(_ backup: BackupLink) -> Bool {
        backup.watch.map { !$0.hasApp } ?? false
    }

    /// Once WatchConnectivity says whether there's a watch: with none, a brand-new player gets
    /// their starter egg here. Either way the widget and reminders are brought up to date.
    private func watchPresenceChanged() {
        if backup.watch?.isPaired == false { pets.grantStarterEggIfNew() }
        PetCompanions.refresh(pets, sendsReminders: Self.sendsReminders(backup))
    }

    static func claimAchievements(_ pets: PetStore, activity: ActivityStore) {
        pets.claimQuests(samples: activity.samples, steps: activity.steps)
        pets.claimAchievements(
            samples: activity.samples, steps: activity.steps, earnings: activity.earnings,
            installDate: activity.installDate)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if welcomed {
                    PhoneRootView()
                } else {
                    WelcomeView { withAnimation { welcomed = true } }
                }
            }
            .fontDesign(.rounded)
            .environment(activity)
            .environment(pets)
            .environment(backup)
            .environment(\.petHome, PetHome(backup.watch))
            // Asks for Health (once the guide is done), then keeps activity current.
            .task(id: welcomed) {
                guard welcomed else { return }
                await activity.start()
            }
            .onChange(of: backup.watch, initial: true) { watchPresenceChanged() }
        }
        .onChange(of: activity.lastRefreshed) { Self.claimAchievements(pets, activity: activity) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await activity.refresh() }
                PetCompanions.refresh(pets, sendsReminders: Self.sendsReminders(backup))
            }
        }
    }
}
