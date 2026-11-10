import FitchiCore
import SwiftUI

/// Today's activity at a glance: Pep earned against the daily soft cap, minutes, workouts and
/// the current balance.
public struct TodaySummaryView: View {
    private let summary: DailySummary
    private let balance: Int
    private let dailyGoal: Int

    public init(summary: DailySummary, balance: Int, dailyGoal: Int) {
        self.summary = summary
        self.balance = balance
        self.dailyGoal = max(1, dailyGoal)
    }

    public var body: some View {
        VStack(spacing: FitchiTheme.Spacing.m) {
            Gauge(value: Double(min(summary.pepEarned, dailyGoal)), in: 0...Double(dailyGoal)) {
                Text("Pep")
            } currentValueLabel: {
                Text("\(summary.pepEarned)")
                    .font(.headline.monospacedDigit())
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(FitchiTheme.Colors.points)
            .accessibilityLabel("\(summary.pepEarned) Pep earned today")

            HStack(spacing: FitchiTheme.Spacing.l) {
                stat("\(summary.activeMinutes)", label: "active min", systemImage: "figure.walk")
                stat(
                    "\(summary.workoutCount)",
                    label: summary.workoutCount == 1 ? "workout" : "workouts",
                    systemImage: "flame.fill"
                )
            }

            Label("\(balance) Pep", systemImage: "sparkles")
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(FitchiTheme.Colors.points)
                .accessibilityLabel("Balance: \(balance) Pep")
        }
    }

    private func stat(_ value: String, label: String, systemImage: String) -> some View {
        VStack(spacing: 2) {
            Label(value, systemImage: systemImage)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TodaySummaryView(
        summary: DailySummary(day: Date(), activeMinutes: 42, workoutCount: 2, pepEarned: 67),
        balance: 167,
        dailyGoal: 180
    )
}
