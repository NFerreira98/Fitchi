import FitchiUI
import SwiftUI

/// Phone tab shell: hub, shop, wardrobe, achievements. Screens are filled in Milestone 6.
struct PhoneRootView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                PetPlaceholderView(name: "Mochi")
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

#Preview {
    PhoneRootView()
}
