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
    @Environment(\.scenePhase) private var scenePhase
    /// When this device last showed the pet, to say hello after time away.
    @AppStorage(PetStage.lastSeenKey) private var lastSeen: Double = 0
    @State private var greeting: PetLife.Greeting?
    private let pet: Pet
    private let species: Species?
    private let mood: PetMood
    private let backdrop: SceneBackdrop.Kind
    private let style: PetLayoutStyle
    private let reaction: StageReaction?
    /// Pet width as a fraction of the stage width (at the front of the ground).
    private let petScale: CGFloat
    /// The watch puts stats and buttons over the bottom of the stage; a stage on its own (the
    /// phone) lets the pet use all the ground down to the bottom edge.
    private let controlsBelow: Bool
    /// A fixed time of day to light the scene for; nil follows the real clock.
    private let fixedLight: SceneLight?
    /// Each change plays the big hello (for trying it out).
    private let bigHellos: Int

    /// UserDefaults key for when the pet was last on screen (seconds since the reference date).
    public static let lastSeenKey = "fitchi.petLastSeen"
    /// Away this long and the pet says hello; this long again and it's a big hello.
    static let greetAfter: TimeInterval = 120
    static let bigGreetAfter: TimeInterval = 4 * 3600

    public init(
        pet: Pet, species: Species?, mood: PetMood = .content, backdrop: SceneBackdrop.Kind = .meadow,
        style: PetLayoutStyle, reaction: StageReaction? = nil, petScale: CGFloat = 0.5, controlsBelow: Bool = true,
        light: SceneLight? = nil, bigHellos: Int = 0
    ) {
        self.bigHellos = bigHellos
        self.controlsBelow = controlsBelow
        self.fixedLight = light
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
                    let ground = groundBand(in: size)
                    let light = fixedLight ?? SceneLight(at: timeline.date)
                    // Farther back is higher up the ground and a little smaller.
                    let drawn = petSize * (1 - depthShrink * (1 - frame.depth))
                    let feet = ground.back + (ground.front - ground.back) * frame.depth
                    let center = CGPoint(
                        x: geometry.size.width / 2 + frame.x * wanderRange(in: geometry.size, petSize: drawn),
                        y: feet - drawn / 2)
                    pet(frame, size: drawn)
                        .position(center)
                    if let visitor = frame.visitor {
                        let kind = backdrop.visitor(in: light)
                        let visitorSize = drawn * (kind == .bird ? 0.26 : 0.22)
                        VisitorView(kind: kind, visitor: visitor)
                            .frame(width: visitorSize, height: visitorSize)
                            .position(x: center.x + visitor.offsetX * drawn, y: feet - visitor.height * drawn)
                    }
                    if let reaction {
                        FloatingReward(text: reaction.floater)
                            .id(reaction.id)
                            .position(x: center.x + drawn * 0.45, y: center.y - drawn * 0.4)
                    }
                }
            }
        }
        .onAppear(perform: arrive)
        .onDisappear(perform: leave)
        .onChange(of: scenePhase) { _, phase in phase == .active ? arrive() : leave() }
        .onChange(of: isLuminanceReduced) { _, dimmed in dimmed ? leave() : arrive() }
        .onChange(of: bigHellos) {
            greeting = PetLife.Greeting(startedAt: Date.now.timeIntervalSinceReferenceDate, isBig: true)
        }
    }

    /// The pet is on screen again: say hello if it's been a while.
    private func arrive() {
        let now = Date.now.timeIntervalSinceReferenceDate
        let away = now - lastSeen
        lastSeen = now
        guard away > Self.greetAfter, reaction == nil, !mood.isAsleep else { return }
        greeting = PetLife.Greeting(startedAt: now + 0.6, isBig: away > Self.bigGreetAfter && !mood.isDown)
    }

    private func leave() {
        lastSeen = Date.now.timeIntervalSinceReferenceDate
    }

    private func frame(at date: Date) -> PetFrame {
        PetLife.frame(
            at: date.timeIntervalSinceReferenceDate, seed: PetLife.seed(for: pet.id), mood: mood,
            reaction: reaction.map {
                PetLife.Reaction(action: $0.action, startedAt: $0.startedAt.timeIntervalSinceReferenceDate)
            },
            still: reduceMotion, visitors: backdrop.hasVisitors, greeting: greeting)
    }

    /// The backdrop, alive: clouds drift, grass sways and the light follows the time of day.
    /// 12 fps is plenty for things this slow; it stops when the wrist is down.
    private var livingBackdrop: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12, paused: isLuminanceReduced)) { timeline in
            SceneBackdrop(
                backdrop, time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate,
                light: fixedLight ?? SceneLight(at: timeline.date))
        }
    }

    @ViewBuilder
    private func pet(_ frame: PetFrame, size: CGFloat) -> some View {
        if let species, PetFigure.hasArt(for: pet.speciesID) {
            // The frame includes the drawing margin, so leaning and walking never reach past it
            // (the watch clips anything drawn outside a moving view's frame).
            PetFigure(
                speciesID: pet.speciesID, palette: PetPalette(species: species, variant: pet.variant), pose: frame.pose,
                effects: frame.effects, accessories: pet.equipped, laysOutMargin: true
            )
            .frame(width: size * PetFigure.marginScale, height: size * PetFigure.marginScale)
        } else {
            Text(species?.emoji ?? "🐾")
                .font(.system(size: 52))
                .offset(y: -frame.pose.lift)
                .frame(width: size, height: size)
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

    /// Where the island's ground sits (the island scene is placed around it).
    private func islandGround(in size: CGSize) -> CGFloat { size.height * 0.70 }

    /// How much smaller the pet is at the very back of the ground.
    private var depthShrink: CGFloat { style == .island ? 0.12 : 0.22 }

    /// The strip of ground the pet's feet can be on, from the back (just below the horizon) to the
    /// front. Backdrops are drawn to the stage's width with the horizon at about 56% of it, so
    /// the ground is found from the width, not guessed from the height.
    private func groundBand(in size: CGSize) -> (back: CGFloat, front: CGFloat) {
        switch style {
        case .island:
            let diameter = min(size.width * 0.95, size.height * 0.8)
            let front = islandGround(in: size)
            return (front - diameter * 0.12, front)
        case .fullScene, .horizon:
            let back = size.width * 0.6
            let front = controlsBelow ? size.height * (style == .horizon ? 0.6 : 0.63) : size.height * 0.93
            return (min(back, front), max(back, front))
        }
    }

    @ViewBuilder
    private func scene(size: CGSize) -> some View {
        switch style {
        case .island:
            let diameter = min(size.width * 0.95, size.height * 0.8)
            livingBackdrop
                .frame(width: diameter, height: diameter)
                .mask(
                    RadialGradient(
                        colors: [.black, .black.opacity(0.9), .clear], center: .center, startRadius: diameter * 0.16,
                        endRadius: diameter / 2)
                )
                .position(x: size.width / 2, y: islandGround(in: size) - diameter * 0.32)
        case .fullScene where !controlsBelow:
            livingBackdrop
        case .fullScene:
            livingBackdrop
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
            livingBackdrop
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
