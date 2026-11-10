import FitchiData
import FitchiHealth
import SwiftUI

@main
struct FitchiWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var activity: ActivityStore
    @State private var pets = PetStore.makeDefault()

    init() {
        let store = ActivityStore.makeDefault(installDate: AppInstall.date())
        _activity = State(initialValue: store)
        // Started here rather than in a view, so a background wake-up from HealthKit (which may
        // not render any UI) still sets up the observer.
        Task { await store.start(backgroundDelivery: true) }
    }

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environment(activity)
                .environment(pets)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await activity.refresh() } }
        }
    }
}
