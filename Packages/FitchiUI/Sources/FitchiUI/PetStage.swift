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
    @State private var boop: PetLife.Boop?
    @State private var boops = 0
    /// A finger on the pet: a quick tap boops it, holding pets it. A swipe cancels.
    @State private var touch: (start: Date, swiped: Bool)?
    @State private var pats = 0
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
    /// 0…1, the glow after a workout (`Afterglow.level`).
    private let afterglow: Double
    /// A fixed season to dress the scene for; nil follows the calendar.
    private let fixedSeason: Season?
    /// Holding longer than this pets instead of booping.
    static let holdToPet: TimeInterval = 0.35

    /// UserDefaults key for when the pet was last on screen (seconds since the reference date).
    public static let lastSeenKey = "fitchi.petLastSeen"
    /// Away this long and the pet says hello; this long again and it's a big hello.
    static let greetAfter: TimeInterval = 120
    static let bigGreetAfter: TimeInterval = 4 * 3600

    public init(
        pet: Pet, species: Species?, mood: PetMood = .content, backdrop: SceneBackdrop.Kind = .meadow,
        style: PetLayoutStyle, reaction: StageReaction? = nil, petScale: CGFloat = 0.5, controlsBelow: Bool = true,
        light: SceneLight? = nil, bigHellos: Int = 0, afterglow: Double = 0, season: Season? = nil
    ) {
        self.fixedSeason = season
        self.afterglow = afterglow
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
                    let light = fixedLight ?? SceneLight(at: timeline.date)
                    let season = fixedSeason ?? Season(at: timeline.date)
                    let (center, drawn) = placement(x: frame.x, depth: frame.depth, in: size, petSize: petSize)
                    let feet = center.y + drawn / 2
                    let footing = backdrop.footing(in: season)
                    // One layer over another; the timeline would otherwise stack them top to bottom.
                    ZStack {
                        GroundMarks(
                            marks: marks(at: timeline.date, footing: footing, in: size, petSize: petSize),
                            footing: footing)
                        pet(frame, size: drawn)
                            // In the same light as the scene, and a touch hazier at the back.
                            .colorMultiply(
                                (backdrop == .starryNight ? .midnight : light).petTint(indoor: backdrop.isIndoor)
                            )
                            .saturation(backdrop.isIndoor ? 1 : 1 - 0.18 * (1 - frame.depth))
                            // Only the pet itself, not the margin around it, takes touches.
                            .contentShape(Rectangle().inset(by: drawn * (PetFigure.marginScale - 1) / 2))
                            .simultaneousGesture(touchGesture)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(pet.name)
                            .accessibilityAction(named: "Boop") { boopNow() }
                            .position(center)
                        if let visitor = frame.visitor {
                            let kind = backdrop.visitor(in: light, season: season)
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
        }
        .onAppear(perform: arrive)
        .onDisappear(perform: leave)
        .onChange(of: scenePhase) { _, phase in phase == .active ? arrive() : leave() }
        .onChange(of: isLuminanceReduced) { _, dimmed in dimmed ? leave() : arrive() }
        .onChange(of: bigHellos) {
            greeting = PetLife.Greeting(startedAt: Date.now.timeIntervalSinceReferenceDate, isBig: true)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: boops)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: pats)
        .task(id: touch?.start) {
            // Still holding after a moment: that's petting. A soft tap says it's noticed.
            guard touch != nil else { return }
            try? await Task.sleep(for: .seconds(Self.holdToPet))
            if let touch, !touch.swiped { pats += 1 }
        }
    }

    private var touchGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let moved = hypot(value.translation.width, value.translation.height) > 12
                if touch == nil {
                    touch = (.now, false)
                } else if moved {
                    touch?.swiped = true
                }
            }
            .onEnded { _ in
                if let touch, !touch.swiped, Date.now.timeIntervalSince(touch.start) < Self.holdToPet {
                    boopNow()
                }
                touch = nil
            }
    }

    private func boopNow() {
        guard reaction == nil else { return }
        boop = PetLife.Boop(startedAt: Date.now.timeIntervalSinceReferenceDate, variety: boops)
        boops += 1
    }

    /// Seconds of petting so far at `date`, once a hold has lasted long enough.
    private func pettedFor(at date: Date) -> Double? {
        guard let touch, !touch.swiped else { return nil }
        let held = date.timeIntervalSince(touch.start) - Self.holdToPet
        return held > 0 ? held : nil
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
            still: reduceMotion, visitors: backdrop.hasVisitors,
            cues: PetLife.Cues(
                greeting: greeting, boop: boop, pettedFor: pettedFor(at: date), afterglow: afterglow),
            personality: pet.personality)
    }

    /// The backdrop, alive: clouds drift, grass sways and the light follows the time of day.
    /// 12 fps is plenty for things this slow; it stops when the wrist is down.
    private var livingBackdrop: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12, paused: isLuminanceReduced)) { timeline in
            SceneBackdrop(
                backdrop, time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate,
                light: fixedLight ?? SceneLight(at: timeline.date), season: fixedSeason ?? Season(at: timeline.date))
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

extension PetStage {
    /// Where on the stage a pet standing at `x`, `depth` is centred, and how big it's drawn:
    /// farther back is higher up the ground and a little smaller.
    private func placement(x: Double, depth: Double, in size: CGSize, petSize: CGFloat) -> (CGPoint, CGFloat) {
        let ground = groundBand(in: size)
        let drawn = petSize * (1 - depthShrink * (1 - depth))
        let feet = ground.back + (ground.front - ground.back) * depth
        return (CGPoint(x: size.width / 2 + x * wanderRange(in: size, petSize: drawn), y: feet - drawn / 2), drawn)
    }

    /// Footprints and dust from recent strolls, placed on the ground. Steps the pet didn't really
    /// take (it was acting out care or dashing over to say hello) are left out.
    private func marks(at date: Date, footing: Footing, in size: CGSize, petSize: CGFloat) -> [GroundMark] {
        guard footing != .none, !reduceMotion else { return [] }
        let now = date.timeIntervalSinceReferenceDate
        var busy: [ClosedRange<TimeInterval>] = []
        if let reaction {
            let start = reaction.startedAt.timeIntervalSinceReferenceDate
            busy.append(start...(start + PetLife.duration(of: reaction.action)))
        }
        if let greeting, greeting.isBig { busy.append(greeting.startedAt...(greeting.startedAt + greeting.duration)) }
        return PetLife.trail(at: now, seed: PetLife.seed(for: pet.id), mood: mood, lasting: footing.lasting)
            .filter { step in !busy.contains { $0.contains(now - step.age) } }
            .map { step in
                let (center, drawn) = placement(x: step.x, depth: step.depth, in: size, petSize: petSize)
                return GroundMark(step: step, point: CGPoint(x: center.x, y: center.y + drawn / 2), petSize: drawn)
            }
    }
}
