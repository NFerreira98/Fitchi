import FitchiData
import FitchiHealth
import FitchiUI
import SwiftUI

@main
struct FitchiWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var activity: ActivityStore
    @State private var pets: PetStore
    @State private var backup: BackupLink

    init() {
        FitchiTheme.Fonts.register()
        let store = ActivityStore.makeDefault(installDate: AppInstall.date())
        let pets = PetStore.makeDefault()
        // Keeps a copy of the game on the iPhone and restores it after a reinstall.
        let backup = BackupLink(
            pets: pets, installDate: { AppInstall.date() },
            adoptInstallDate: { date in
                if AppInstall.adopt(date) { store.adoptInstallDate(date) }
            })
        _activity = State(initialValue: store)
        _pets = State(initialValue: pets)
        _backup = State(initialValue: backup)
        backup.start()
        // Started here rather than in a view, so a background wake-up from HealthKit (which may
        // not render any UI) still sets up the observer.
        Task { await store.start(backgroundDelivery: true) }
    }

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .fontDesign(.rounded)
                .environment(activity)
                .environment(pets)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await activity.refresh() } }
        }
    }
}
