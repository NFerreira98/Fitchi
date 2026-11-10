import FitchiHealth
import FitchiUI
import SwiftUI

/// Watch home hub: the pet on the first page, today's activity on the next.
/// Stats, feeding and the mini shop arrive in Milestone 5.
struct WatchHomeView: View {
    var body: some View {
        NavigationStack {
            TabView {
                PetPlaceholderView(name: "Mochi")
                    .navigationTitle("Fitchi")
                WatchTodayView()
                    .navigationTitle("Today")
            }
            .tabViewStyle(.verticalPage)
        }
    }
}

/// Pep and minutes earned today, or why they can't be shown.
struct WatchTodayView: View {
    @Environment(ActivityStore.self) private var activity

    var body: some View {
        switch activity.status {
        case .idle, .loading:
            ProgressView()
        case .unavailable:
            ContentUnavailableView(
                "No Health data",
                systemImage: "heart.slash",
                description: Text("Health isn't available on this device.")
            )
        case .failed(let message):
            VStack(spacing: FitchiTheme.Spacing.s) {
                Text(message)
                    .multilineTextAlignment(.center)
                    .font(.footnote)
                Button("Try again") { Task { await activity.start() } }
            }
        case .ready:
            ScrollView {
                TodaySummaryView(
                    summary: activity.today,
                    balance: activity.wallet.balance,
                    dailyGoal: Int(activity.rules.dailySoftCap)
                )
                if let updated = activity.lastRefreshed {
                    Text("Updated \(updated, style: .time)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, FitchiTheme.Spacing.s)
                }
            }
        }
    }
}

#Preview {
    WatchHomeView()
        .environment(ActivityStore.preview())
}
