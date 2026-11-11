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

/// A pet "moment" the stage acts out: a hop plus a reward floating up.
public struct StageReaction: Equatable, Sendable {
    public let id: UUID
    public let floater: String

    public init(id: UUID = UUID(), floater: String) {
        self.id = id
        self.floater = floater
    }
}

/// The pet living in its scene: backdrop, idling pet, hop and floating reward. Layouts decide
/// how much of the scene shows (`style`) and where controls go; the stage itself is shared by
/// the watch and the phone.
public struct PetStage: View {
    private let pet: Pet
    private let species: Species?
    private let backdrop: SceneBackdrop.Kind
    private let style: PetLayoutStyle
    private let reaction: StageReaction?
    /// Pet width as a fraction of the stage width.
    private let petScale: CGFloat
    @State private var excited = false

    public init(
        pet: Pet, species: Species?, backdrop: SceneBackdrop.Kind = .meadow, style: PetLayoutStyle,
        reaction: StageReaction? = nil, petScale: CGFloat = 0.5
    ) {
        self.pet = pet
        self.species = species
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
                LivingPetView(
                    species: species, speciesID: pet.speciesID, variant: pet.variant, excited: excited, seed: pet.id
                )
                .frame(width: petSize, height: petSize)
                .hop(on: reaction?.id)
                .position(x: size.width / 2, y: groundY(in: size) - petSize / 2)
                if let reaction {
                    FloatingReward(text: reaction.floater)
                        .id(reaction.id)
                        .position(x: size.width / 2 + petSize * 0.45, y: groundY(in: size) - petSize * 0.9)
                }
            }
        }
        .task(id: reaction?.id) {
            guard reaction != nil else { return }
            excited = true
            try? await Task.sleep(for: .seconds(1.6))
            excited = false
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

extension View {
    /// A squash-and-stretch hop each time `trigger` changes (skipped with Reduce Motion).
    func hop(on trigger: UUID?) -> some View {
        modifier(HopModifier(trigger: trigger))
    }
}

private struct HopModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let trigger: UUID?

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: HopState(), trigger: reduceMotion ? nil : trigger) { content, hop in
            content
                .scaleEffect(x: hop.squash, y: 2 - hop.squash, anchor: .bottom)
                .offset(y: hop.lift)
        } keyframes: { _ in
            KeyframeTrack(\.lift) {
                CubicKeyframe(0, duration: 0.08)
                SpringKeyframe(-16, duration: 0.2)
                SpringKeyframe(0, duration: 0.35, spring: .bouncy)
            }
            KeyframeTrack(\.squash) {
                CubicKeyframe(1.15, duration: 0.08)
                CubicKeyframe(0.92, duration: 0.2)
                SpringKeyframe(1, duration: 0.35, spring: .bouncy)
            }
        }
    }
}

struct HopState {
    var lift: Double = 0
    var squash: Double = 1
}
