import FitchiCore
import SwiftUI

/// A round badge with the achievement's symbol: gold when unlocked, grey until then.
public struct AchievementBadge: View {
    private let achievement: Achievement
    private let unlocked: Bool
    private let size: CGFloat

    public init(_ achievement: Achievement, unlocked: Bool, size: CGFloat = 44) {
        self.achievement = achievement
        self.unlocked = unlocked
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(
                    unlocked
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1, green: 0.84, blue: 0.4), Color(red: 0.95, green: 0.62, blue: 0.15),
                                ],
                                startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Color.gray.opacity(0.2)))
            Image(systemName: achievement.icon ?? "trophy.fill")
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(unlocked ? .white : .secondary)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// "Achievement unlocked!" with the badge, name and reward. Shown once per unlock.
public struct AchievementCelebration: View {
    private let achievement: Achievement
    private let compact: Bool

    /// `compact` for the watch.
    public init(_ achievement: Achievement, compact: Bool = false) {
        self.achievement = achievement
        self.compact = compact
    }

    public var body: some View {
        VStack(spacing: compact ? 4 : 8) {
            AchievementBadge(achievement, unlocked: true, size: compact ? 44 : 64)
            Text("Achievement unlocked!")
                .font(FitchiTheme.Fonts.text(compact ? .caption2 : .subheadline, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(achievement.name)
                .font(FitchiTheme.Fonts.display(compact ? .headline : .title2))
                .multilineTextAlignment(.center)
            Text("+\(achievement.reward) Pep")
                .font(FitchiTheme.Fonts.display(compact ? .subheadline : .headline).monospacedDigit())
                .foregroundStyle(FitchiTheme.Colors.points)
        }
        .padding(compact ? 12 : 20)
        .frame(maxWidth: compact ? .infinity : 320)
        .background(.regularMaterial, in: .rect(cornerRadius: compact ? 20 : 28))
        .overlay {
            ShinyBurst().allowsHitTesting(false)
        }
        .accessibilityElement(children: .combine)
    }
}
