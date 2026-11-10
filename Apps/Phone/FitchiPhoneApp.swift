import FitchiData
import FitchiHealth
import SwiftUI

@main
struct FitchiPhoneApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var activity = ActivityStore.makeDefault(installDate: AppInstall.date())

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .environment(activity)
                .task { await activity.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await activity.refresh() } }
        }
    }
}
