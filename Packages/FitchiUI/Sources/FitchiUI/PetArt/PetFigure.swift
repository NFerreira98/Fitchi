import FitchiCore
import SwiftUI

/// A pet drawn as smooth vector art at any size. The same drawing serves every colour variant;
/// animations change `pose` frame by frame.
public struct PetFigure: View {
    private let speciesID: String
    private let palette: PetPalette
    private let pose: PetPose
    private let effects: PetEffects
    private let laysOutMargin: Bool
    private let accessories: [AccessorySlot: String]

    /// `laysOutMargin` makes the view's own frame include the `overdraw` margin (the art square
    /// is the middle 100/160 of it), so nothing is ever drawn outside the frame. Use it wherever
    /// the pet moves; otherwise the view lays out as the art square and the margin spills over.
    public init(
        speciesID: String, palette: PetPalette, pose: PetPose = .standing, effects: PetEffects = .none,
        accessories: [AccessorySlot: String] = [:], laysOutMargin: Bool = false
    ) {
        self.accessories = accessories
        self.speciesID = speciesID
        self.palette = palette
        self.pose = pose
        self.effects = effects
        self.laysOutMargin = laysOutMargin
    }

    /// How much bigger than the art square the frame is when `laysOutMargin` is set.
    public static let marginScale: CGFloat = 1 + overdraw * 2 / 100

    /// Extra drawing room around the 100×100 art, in art units. Leaning, hopping and stretching
    /// carry tails, gills and props past the art square; without this margin the canvas would
    /// slice them off in a straight line.
    static let overdraw: CGFloat = 30

    @ViewBuilder
    public var body: some View {
        if laysOutMargin {
            canvas
                .aspectRatio(1, contentMode: .fit)
                .accessibilityHidden(true)
        } else {
            spillingBody
        }
    }

    private var spillingBody: some View {
        // Lays out as the art square, but draws into a canvas `overdraw` larger on every side.
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    let side = min(geometry.size.width, geometry.size.height)
                    let margin = side * Self.overdraw / 100
                    canvas
                        .frame(width: side + margin * 2, height: side + margin * 2)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }
            .accessibilityHidden(true)
    }

    private var canvas: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / (100 + Self.overdraw * 2)
            context.translateBy(
                x: (size.width - 100 * scale) / 2, y: (size.height - 100 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            drawShadow(context)
            // Asleep: lower and flatter, head resting down.
            var drawn = pose
            drawn.squash += 0.1 * pose.sleep
            drawn.headBob += 3 * pose.sleep
            var posed = context
            let ground = Ink.ground
            posed.translateBy(x: 50, y: ground - drawn.lift)
            posed.rotate(by: .degrees(drawn.tilt))
            posed.scaleBy(x: (1 + drawn.squash * 0.6) * (drawn.flipped ? -1 : 1), y: 1 - drawn.squash)
            posed.translateBy(x: -50, y: -ground)
            let fit = PetFit.fit(for: speciesID)
            AccessoryArt.drawBehind(accessories, Ink(context: posed), fit: fit)
            Self.painter(for: speciesID)(Ink(context: posed), palette, drawn)
            AccessoryArt.drawInFront(accessories, Ink(context: posed), fit: fit, headBob: drawn.headBob)
            EffectArt.drawOnBody(effects, posed)
            if palette.isShiny { Sparkles.draw(context) }
            EffectArt.drawAround(effects, context, flipped: drawn.flipped)
        }
        .allowsHitTesting(false)
    }

    private func drawShadow(_ context: GraphicsContext) {
        let shrink = max(0.5, 1 - pose.lift / 30)
        let shadow = Path(ellipse: CGPoint(x: 50, y: Ink.ground - 1), rx: 26 * shrink, ry: 4.5 * shrink)
        context.fill(shadow, with: .color(.black.opacity(0.18)))
    }

    /// Whether a drawing exists for this species; others still show their emoji.
    public static func hasArt(for speciesID: String) -> Bool {
        painters[speciesID] != nil
    }

    private static let painters: [String: (Ink, PetPalette, PetPose) -> Void] = [
        "axolotl": AxolotlArt.draw,
        "cat": CatArt.draw,
        "dog": DogArt.draw,
        "bunny": BunnyArt.draw,
        "red-panda": RedPandaArt.draw,
        "penguin": PenguinArt.draw,
        "platypus": PlatypusArt.draw,
        "golden-axolotl": AxolotlArt.drawLegendary,
    ]

    static func painter(for speciesID: String) -> (Ink, PetPalette, PetPose) -> Void {
        painters[speciesID] ?? DogArt.draw
    }
}

/// Four-point twinkles that mark a shiny.
enum Sparkles {
    static let spots: [(CGPoint, CGFloat)] = [
        (CGPoint(x: 12, y: 22), 5), (CGPoint(x: 88, y: 18), 4), (CGPoint(x: 90, y: 46), 2.6), (CGPoint(x: 9, y: 60), 3),
    ]

    static func draw(_ context: GraphicsContext) {
        for (center, size) in spots {
            context.fill(star(at: center, size: size), with: .color(Color(red: 1, green: 0.9, blue: 0.45)))
            context.fill(star(at: center, size: size * 0.45), with: .color(.white))
        }
    }

    static func star(at center: CGPoint, size: CGFloat) -> Path {
        var path = Path()
        let waist = size * 0.22
        path.move(to: CGPoint(x: center.x, y: center.y - size))
        path.addQuadCurve(
            to: CGPoint(x: center.x + size, y: center.y), control: CGPoint(x: center.x + waist, y: center.y - waist))
        path.addQuadCurve(
            to: CGPoint(x: center.x, y: center.y + size), control: CGPoint(x: center.x + waist, y: center.y + waist))
        path.addQuadCurve(
            to: CGPoint(x: center.x - size, y: center.y), control: CGPoint(x: center.x - waist, y: center.y + waist))
        path.addQuadCurve(
            to: CGPoint(x: center.x, y: center.y - size), control: CGPoint(x: center.x - waist, y: center.y - waist))
        return path
    }
}
