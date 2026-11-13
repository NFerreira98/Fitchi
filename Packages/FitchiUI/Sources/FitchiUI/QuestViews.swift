import FitchiCore
import SwiftUI

extension QuestGoal {
    /// "Walk 1,000 steps before 10 am".
    public func title(petName: String) -> String {
        switch self {
        case .stepsBefore(let steps, let hour): "Walk \(steps.formatted()) steps before \(Self.clock(hour))"
        case .stepsAfter(let steps, let hour): "Walk \(steps.formatted()) steps after \(Self.clock(hour))"
        case .steps(let steps): "Reach \(steps.formatted()) steps"
        case .activeMinutes(let minutes, nil): "\(minutes) active minutes"
        case .activeMinutes(let minutes, let hour?): "\(minutes) active minutes before \(Self.clock(hour))"
        case .workout: "Do a workout"
        case .care(.feed): "Feed \(petName)"
        case .care(.play): "Play with \(petName)"
        case .care(.wash): "Give \(petName) a bath"
        case .care(.rest): "Tuck \(petName) in for a nap"
        case .gifts(let count): "Collect \(count) gifts from \(petName)"
        }
    }

    public var symbol: String {
        switch self {
        case .stepsBefore: "sunrise.fill"
        case .stepsAfter: "sunset.fill"
        case .steps: "figure.walk"
        case .activeMinutes: "flame.fill"
        case .workout: "figure.run"
        case .care(let action):
            action == .feed ? "fork.knife" : action == .wash ? "bubbles.and.sparkles.fill" : "heart.fill"
        case .gifts: "gift.fill"
        }
    }

    /// Whether progress is a count worth showing ("600 / 1,000").
    var showsCount: Bool {
        switch self {
        case .stepsBefore, .stepsAfter, .steps, .activeMinutes, .gifts: true
        case .workout, .care: false
        }
    }

    static func clock(_ hour: Int) -> String {
        hour == 12 ? "noon" : hour < 12 ? "\(hour) am" : "\(hour - 12) pm"
    }
}

/// One quest with its progress and reward.
public struct QuestRow: View {
    private let goal: QuestGoal
    private let reward: Int
    private let current: Double
    private let target: Double
    private let petName: String
    private let compact: Bool

    public init(
        goal: QuestGoal, reward: Int, current: Double, target: Double, petName: String, compact: Bool = false
    ) {
        self.goal = goal
        self.reward = reward
        self.current = current
        self.target = target
        self.petName = petName
        self.compact = compact
    }

    private var isDone: Bool { current >= target }

    public var body: some View {
        HStack(spacing: compact ? 6 : FitchiTheme.Spacing.m) {
            Image(systemName: isDone ? "checkmark.circle.fill" : goal.symbol)
                .font(.system(size: compact ? 15 : 20, weight: .semibold))
                .foregroundStyle(isDone ? .green : FitchiTheme.Colors.accent)
                .frame(width: compact ? 20 : 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title(petName: petName))
                    .font(FitchiTheme.Fonts.text(compact ? .footnote : .subheadline, weight: .semibold))
                    .strikethrough(isDone, color: .secondary)
                    .foregroundStyle(isDone ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                if !isDone {
                    ProgressView(value: min(current, target), total: max(target, 1))
                        .tint(FitchiTheme.Colors.accent)
                    if goal.showsCount {
                        Text("\(Int(min(current, target)).formatted()) / \(Int(target).formatted())")
                            .font(FitchiTheme.Fonts.text(.caption2).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
            Text("+\(reward)")
                .font(FitchiTheme.Fonts.display(compact ? .footnote : .subheadline).monospacedDigit())
                .foregroundStyle(isDone ? .secondary : FitchiTheme.Colors.points)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The streak and this week's ladder: six growing Pep rewards and an egg at the top. Done days
/// are filled; the next one to earn is outlined.
public struct StreakLadderView: View {
    private let streak: Int
    private let todayDone: Bool
    private let ladder: StreakLadder
    private let compact: Bool

    public init(streak: Int, todayDone: Bool, ladder: StreakLadder = .v1, compact: Bool = false) {
        self.streak = streak
        self.todayDone = todayDone
        self.ladder = ladder
        self.compact = compact
    }

    /// The streak day the ladder shows as "next": today's, or tomorrow's once today is done.
    private var nextDay: Int { streak + 1 }
    /// Which week to show: the one today's climb is in (or just finished).
    private var shownDay: Int { todayDone ? max(streak, 1) : nextDay }
    private var filled: Int {
        todayDone ? (max(streak, 1) - 1) % ladder.length + 1 : (nextDay - 1) % ladder.length
    }

    public var body: some View {
        let rungs = ladder.rungs(forWeek: ladder.week(ofDay: shownDay))
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill").foregroundStyle(streak > 0 ? .orange : .secondary)
                Text(streak == 1 ? "1-day streak" : "\(streak)-day streak")
                    .font(FitchiTheme.Fonts.display(compact ? .subheadline : .headline).monospacedDigit())
            }
            HStack(spacing: compact ? 3 : 6) {
                ForEach(Array(rungs.enumerated()), id: \.offset) { index, reward in
                    rung(reward, done: index < filled, isNext: !todayDone && index == filled)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(rungs))
    }

    private func rung(_ reward: StreakReward, done: Bool, isNext: Bool) -> some View {
        let isEgg: Bool = if case .egg = reward { true } else { false }
        return VStack(spacing: 1) {
            switch reward {
            case .pep(let amount):
                Text("\(amount)")
                    .font(FitchiTheme.Fonts.display(size: compact ? 11 : 15, weight: .bold).monospacedDigit())
            case .egg(let id):
                EggFigure()
                    .frame(width: compact ? 14 : 20, height: compact ? 16 : 22)
                    .overlay(alignment: .topTrailing) {
                        if id == ladder.bigEgg {
                            Text("★").font(.system(size: compact ? 7 : 10)).foregroundStyle(.yellow)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 26 : 38)
        .background(
            RoundedRectangle(cornerRadius: compact ? 6 : 9)
                .fill(done ? AnyShapeStyle(FitchiTheme.Colors.points.opacity(0.9)) : AnyShapeStyle(.fill.tertiary))
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 6 : 9)
                .stroke(isNext ? FitchiTheme.Colors.accent : .clear, lineWidth: 2)
        )
        .foregroundStyle(done ? .black : .primary)
        .scaleEffect(isEgg ? 1.08 : 1)
    }

    private func accessibilityText(_ rungs: [StreakReward]) -> String {
        let next = ladder.reward(forDay: nextDay)
        let nextText: String =
            switch next {
            case .pep(let amount): "\(amount) Pep"
            case .egg(let id): EggName.display(id)
            }
        return "\(streak)-day streak. \(todayDone ? "Tomorrow" : "Today")'s reward: \(nextText)."
    }
}

/// "sparkle-egg" → "Sparkle Egg", for when the catalog isn't at hand.
public enum EggName {
    public static func display(_ id: String) -> String {
        id.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

/// A quest or streak-reward celebration card. Shown once per notice.
public struct QuestNoticeCard: View {
    private let symbol: String
    private let headline: String
    private let title: String
    private let pep: Int
    private let compact: Bool

    public init(_ notice: QuestNotice, petName: String, compact: Bool = false) {
        switch notice {
        case .quest(let quest):
            self.init(
                symbol: quest.goal.symbol, headline: "Quest complete!", title: quest.goal.title(petName: petName),
                pep: quest.reward, compact: compact)
        case .allDone(.pep(let pep), let streak):
            self.init(
                symbol: "flame.fill", headline: "All quests done!",
                title: streak > 1 ? "Day \(streak) of your streak" : "Streak started", pep: pep, compact: compact)
        case .allDone(.egg(let eggID), let streak):
            self.init(
                symbol: "gift.fill", headline: "Day \(streak) streak reward!",
                title: "A free \(EggName.display(eggID))",
                pep: 0, compact: compact)
        }
    }

    public init(symbol: String, headline: String, title: String, pep: Int, compact: Bool = false) {
        self.symbol = symbol
        self.headline = headline
        self.title = title
        self.pep = pep
        self.compact = compact
    }

    public var body: some View {
        VStack(spacing: compact ? 3 : 6) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 26 : 36, weight: .bold))
                .foregroundStyle(FitchiTheme.Colors.accent)
            Text(headline)
                .font(FitchiTheme.Fonts.text(compact ? .caption2 : .subheadline, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(FitchiTheme.Fonts.display(compact ? .headline : .title3))
                .multilineTextAlignment(.center)
            if pep > 0 {
                Text("+\(pep) Pep")
                    .font(FitchiTheme.Fonts.display(compact ? .subheadline : .headline).monospacedDigit())
                    .foregroundStyle(FitchiTheme.Colors.points)
            } else {
                Text("Hatch it in Fitchi on your iPhone")
                    .font(FitchiTheme.Fonts.text(compact ? .caption2 : .footnote))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(compact ? 12 : 18)
        .frame(maxWidth: compact ? .infinity : 320)
        .background(.regularMaterial, in: .rect(cornerRadius: compact ? 20 : 26))
        .accessibilityElement(children: .combine)
    }
}

/// A wrapped present that bobs gently: the pet found something. Tap to collect.
public struct GiftBubble: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let isLucky: Bool

    public init(isLucky: Bool = false) {
        self.isLucky = isLucky
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Text(isLucky ? "🪙" : "🎁")
                .font(.system(size: 22))
                .padding(7)
                .background(Circle().fill(.white.opacity(0.92)))
                .overlay(Circle().stroke(FitchiTheme.Colors.points, lineWidth: 2))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
                .offset(y: reduceMotion ? 0 : sin(time * 3) * 3)
                .rotationEffect(.degrees(reduceMotion ? 0 : sin(time * 1.7) * 6))
        }
        .accessibilityLabel(isLucky ? "A lucky find" : "A gift")
    }
}
