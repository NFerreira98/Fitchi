import FitchiData
import FitchiHealth
import FitchiUI
import SwiftUI

@main
struct FitchiPhoneApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var activity = ActivityStore.makeDefault(installDate: AppInstall.date())

    init() {
        FitchiTheme.Fonts.register()
    }

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .fontDesign(.rounded)
                .environment(activity)
                .task { await activity.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await activity.refresh() } }
        }
    }
}
