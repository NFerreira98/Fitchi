import SwiftUI

/// A pet drawn as smooth vector art at any size. The same drawing serves every colour variant;
/// animations change `pose` frame by frame.
public struct PetFigure: View {
    private let speciesID: String
    private let palette: PetPalette
    private let pose: PetPose

    public init(speciesID: String, palette: PetPalette, pose: PetPose = .standing) {
        self.speciesID = speciesID
        self.palette = palette
        self.pose = pose
    }

    public var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 100
            context.translateBy(x: (size.width - 100 * scale) / 2, y: (size.height - 100 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            drawShadow(context)
            var posed = context
            let ground = Ink.ground
            posed.translateBy(x: 50, y: ground - pose.lift)
            posed.scaleBy(x: 1 + pose.squash * 0.6, y: 1 - pose.squash)
            posed.translateBy(x: -50, y: -ground)
            Self.painter(for: speciesID)(Ink(context: posed), palette, pose)
            if palette.isShiny { Sparkles.draw(context) }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
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
