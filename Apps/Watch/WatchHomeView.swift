import FitchiUI
import SwiftUI

/// Watch home hub where the pet lives. Stats, feeding and the mini shop arrive in Milestone 5.
struct WatchHomeView: View {
    var body: some View {
        NavigationStack {
            PetPlaceholderView(name: "Mochi")
                .navigationTitle("Fitchi")
        }
    }
}

#Preview {
    WatchHomeView()
}
