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

    init() {
        FitchiTheme.Fonts.register()
        let store = ActivityStore.makeDefault(installDate: AppInstall.date())
        // The phone doesn't hatch its own egg: it keeps a backup of the watch's game.
        let pets = PetStore.makeDefault(grantsStarterEgg: false)
        let backup = BackupLink(
            pets: pets, installDate: { AppInstall.date() },
            adoptInstallDate: { date in
                if AppInstall.adopt(date) { store.adoptInstallDate(date) }
            })
        _activity = State(initialValue: store)
        _pets = State(initialValue: pets)
        _backup = State(initialValue: backup)
        backup.start()
    }

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .fontDesign(.rounded)
                .environment(activity)
                .environment(pets)
                .environment(backup)
                .task { await activity.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await activity.refresh() } }
        }
    }
}
