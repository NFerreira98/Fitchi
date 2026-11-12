import FitchiCore
import SwiftUI

/// How the pet screen is arranged. A display preference (Settings), not a purchase: some people
/// find one layout easier to read or calmer to look at than another.
public enum PetLayoutStyle: String, CaseIterable, Identifiable, Sendable {
    /// The pet on a glowing patch of its world, on black. Calm and high-contrast.
    case island
    /// The world fills the screen and fades into black behind the controls.
    case fullScene
    /// The world across the top, stats and controls on plain black below. Easiest to read.
    case horizon

    public var id: String { rawValue }

    /// UserDefaults key for `@AppStorage`.
    public static let storageKey = "fitchi.petLayoutStyle"

    public var title: String {
        switch self {
        case .island: "Island"
        case .fullScene: "Full scene"
        case .horizon: "Horizon"
        }
    }

    public var summary: String {
        switch self {
        case .island: "Your pet on a glowing patch of its world. Calm, high contrast."
        case .fullScene: "The whole screen is your pet's world."
        case .horizon: "Scene on top, stats and buttons on black. Easiest to read."
        }
    }
}

/// A care moment the stage acts out (a bowl, a ball, bubbles or a nap) with a reward floating up.
public struct StageReaction: Equatable, Sendable {
    public let id: UUID
    /// nil for a generic happy wiggle.
    public let action: CareAction?
    public let floater: String
    public let startedAt: Date

    public init(id: UUID = UUID(), action: CareAction? = nil, floater: String, startedAt: Date = .now) {
        self.id = id
        self.action = action
        self.floater = floater
        self.startedAt = startedAt
    }
}

/// The pet living in its scene: backdrop, a pet that wanders, naps and shows its mood, care
/// animations and floating rewards. Layouts decide how much of the scene shows (`style`) and
/// where controls go; the stage itself is shared by the watch and the phone.
public struct PetStage: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let pet: Pet
    private let species: Species?
    private let mood: PetMood
    private let backdrop: SceneBackdrop.Kind
    private let style: PetLayoutStyle
    private let reaction: StageReaction?
    /// Pet width as a fraction of the stage width.
    private let petScale: CGFloat

    public init(
        pet: Pet, species: Species?, mood: PetMood = .content, backdrop: SceneBackdrop.Kind = .meadow,
        style: PetLayoutStyle, reaction: StageReaction? = nil, petScale: CGFloat = 0.5
    ) {
        self.pet = pet
        self.species = species
        self.mood = mood
        self.backdrop = backdrop
        self.style = style
        self.reaction = reaction
        self.petScale = petScale
    }

    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let petSize = size.width * petScale
            ZStack {
                scene(size: size)
                // 20 fps is plenty for a gentle pet; it stops when the wrist is down. Reduce Motion
                // ticks slowly, just enough to end care moments.
                TimelineView(
                    .animation(minimumInterval: reduceMotion ? 0.5 : 1.0 / 20, paused: isLuminanceReduced)
                ) { timeline in
                    let frame = frame(at: timeline.date)
                    let center = CGPoint(
                        x: size.width / 2 + frame.x * wanderRange(in: size, petSize: petSize),
                        y: groundY(in: size) - petSize / 2)
                    pet(frame)
                        .frame(width: petSize, height: petSize)
                        .position(center)
                    if let reaction {
                        FloatingReward(text: reaction.floater)
                            .id(reaction.id)
                            .position(x: center.x + petSize * 0.45, y: center.y - petSize * 0.4)
                    }
                }
            }
        }
    }

    private func frame(at date: Date) -> PetFrame {
        PetLife.frame(
            at: date.timeIntervalSinceReferenceDate, seed: PetLife.seed(for: pet.id), mood: mood,
            reaction: reaction.map {
                PetLife.Reaction(action: $0.action, startedAt: $0.startedAt.timeIntervalSinceReferenceDate)
            },
            still: reduceMotion)
    }

    @ViewBuilder
    private func pet(_ frame: PetFrame) -> some View {
        if let species, PetFigure.hasArt(for: pet.speciesID) {
            PetFigure(
                speciesID: pet.speciesID, palette: PetPalette(species: species, variant: pet.variant), pose: frame.pose,
                effects: frame.effects)
        } else {
            Text(species?.emoji ?? "🐾")
                .font(.system(size: 52))
                .offset(y: -frame.pose.lift)
                .accessibilityHidden(true)
        }
    }

    /// How far either side of centre the pet strolls.
    private func wanderRange(in size: CGSize, petSize: CGFloat) -> CGFloat {
        switch style {
        case .island: max(0, min(size.width * 0.95, size.height * 0.8) * 0.42 - petSize / 2)
        case .fullScene, .horizon: max(0, size.width * 0.42 - petSize / 2)
        }
    }

    /// Where the pet's feet touch the ground.
    private func groundY(in size: CGSize) -> CGFloat {
        switch style {
        case .island: size.height * 0.70
        case .fullScene: size.height * 0.58
        case .horizon: size.height * 0.56
        }
    }

    @ViewBuilder
    private func scene(size: CGSize) -> some View {
        switch style {
        case .island:
            let diameter = min(size.width * 0.95, size.height * 0.8)
            SceneBackdrop(backdrop)
                .frame(width: diameter, height: diameter)
                .mask(
                    RadialGradient(
                        colors: [.black, .black.opacity(0.9), .clear], center: .center, startRadius: diameter * 0.16,
                        endRadius: diameter / 2)
                )
                .position(x: size.width / 2, y: groundY(in: size) - diameter * 0.32)
        case .fullScene:
            SceneBackdrop(backdrop)
                .mask(
                    LinearGradient(
                        stops: [.init(color: .black, location: 0.6), .init(color: .clear, location: 0.95)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(alignment: .top) {
                    // Keeps the name and Pep readable over a bright sky.
                    LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: size.height * 0.3)
                }
        case .horizon:
            SceneBackdrop(backdrop)
                .frame(height: size.height * 0.64)
                .mask(
                    LinearGradient(
                        stops: [.init(color: .black, location: 0.7), .init(color: .clear, location: 1)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(alignment: .top) {
                    LinearGradient(colors: [.black.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: size.height * 0.3)
                }
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

/// A small ring showing one stat, for the corners of the pet screen.
public struct StatRing: View {
    private let stat: Stat
    private let value: Double

    public init(_ stat: Stat, value: Double) {
        self.stat = stat
        self.value = value
    }

    public var body: some View {
        ZStack {
            Circle().stroke(stat.color.opacity(0.25), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(0.02, min(value / 100, 1)))
                .stroke(stat.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: stat.systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(stat.color)
        }
        .frame(width: 24, height: 24)
        .animation(.spring(duration: 0.6), value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.title): \(Int(value.rounded())) out of 100")
    }
}

/// A thin labelled bar, for the Horizon layout.
public struct StatPip: View {
    private let stat: Stat
    private let value: Double

    public init(_ stat: Stat, value: Double) {
        self.stat = stat
        self.value = value
    }

    public var body: some View {
        VStack(spacing: 2) {
            Capsule()
                .fill(stat.color.opacity(0.25))
                .overlay(alignment: .leading) {
                    GeometryReader { geometry in
                        Capsule().fill(stat.color).frame(width: geometry.size.width * max(0.04, min(value / 100, 1)))
                    }
                }
                .frame(height: 5)
            Image(systemName: stat.systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(stat.color)
        }
        .animation(.spring(duration: 0.6), value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.title): \(Int(value.rounded())) out of 100")
    }
}

/// Rises and fades out once.
struct FloatingReward: View {
    let text: String
    @State private var risen = false

    var body: some View {
        Text(text)
            .font(FitchiTheme.Fonts.display(.headline, weight: .heavy).monospacedDigit())
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 2)
            .offset(y: risen ? -30 : 0)
            .opacity(risen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.4)) { risen = true }
            }
            .accessibilityHidden(true)
    }
}
