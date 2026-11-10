import FitchiHealth
import FitchiUI
import SwiftUI

/// Phone tab shell: hub, shop, wardrobe, achievements. Screens are filled in Milestone 6.
struct PhoneRootView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                PhoneHomeView()
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

struct PhoneHomeView: View {
    @Environment(ActivityStore.self) private var activity

    var body: some View {
        ScrollView {
            VStack(spacing: FitchiTheme.Spacing.l * 2) {
                PetPlaceholderView(name: "Mochi")
                    .padding(.top, FitchiTheme.Spacing.l * 2)
                today
                    .frame(maxWidth: .infinity)
                    .padding(FitchiTheme.Spacing.l)
                    .background(.fill.tertiary, in: .rect(cornerRadius: 20))
            }
            .padding(FitchiTheme.Spacing.l)
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
                    balance: activity.wallet.balance,
                    dailyGoal: Int(activity.rules.dailySoftCap)
                )
            }
        }
    }
}

#Preview {
    PhoneRootView()
        .environment(ActivityStore.preview())
}
