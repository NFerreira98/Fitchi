import SwiftUI

/// Wide smiley head, feathery gill fronds, a curled fin tail.
enum AxolotlArt {
    static func draw(_ ink: Ink, palette: PetPalette, pose: PetPose) {
        draw(ink, palette: palette, pose: pose, regal: false)
    }

    /// The legendary Golden Axolotl: a glowing aura, a fin crest over the head, longer flowing
    /// gills (four per side) and a gem on the brow (`bow` colour).
    static func drawLegendary(_ ink: Ink, palette: PetPalette, pose: PetPose) {
        draw(ink, palette: palette, pose: pose, regal: true)
    }

    private static func draw(_ ink: Ink, palette: PetPalette, pose: PetPose, regal: Bool) {
        let skin = Tone(palette.body)
        let belly = Tone(palette.belly)
        let gills = Tone(palette.accent)

        if regal { aura(ink, color: palette.accent) }
        let tailPivot = CGPoint(x: 64, y: 76)
        ink.part(tail.rotated(degrees: pose.tailAngle, around: tailPivot), skin)
        ink.part(Path(ellipse: CGPoint(x: 37, y: 89), rx: 7, ry: 4.5), skin, shaded: false)
        ink.part(Path(ellipse: CGPoint(x: 63, y: 89), rx: 7, ry: 4.5), skin, shaded: false)
        ink.part(Path(ellipse: CGPoint(x: 50, y: 76), rx: 21, ry: 15), skin)
        ink.part(Path(ellipse: CGPoint(x: 50, y: 80), rx: 12, ry: 8.5), belly, shaded: false, outlined: false)
        ink.part(Path(ellipse: CGPoint(x: 31, y: 77), rx: 4.5, ry: 7, degrees: 30), skin, shaded: false)
        ink.part(Path(ellipse: CGPoint(x: 69, y: 77), rx: 4.5, ry: 7, degrees: -30), skin, shaded: false)
        if let marking = palette.marking {
            spots(ink, marking, at: [CGPoint(x: 42, y: 70), CGPoint(x: 58, y: 73), CGPoint(x: 77, y: 70)])
        }

        var head = ink
        head.context.translateBy(x: 0, y: pose.headBob)
        let flutter = pose.earAngle
        if regal { head.part(crest(flutter: flutter), gills, gloss: true) }
        head.part(gillFronds(flutter: flutter, regal: regal), gills, gloss: true)
        head.part(gillFronds(flutter: flutter, regal: regal).mirrored, gills, gloss: true)
        head.part(Path(ellipse: CGPoint(x: 50, y: 46), rx: 33, ry: 24), skin, gloss: true)
        if regal, let gem = palette.bow { self.gem(head, color: gem) }
        if let marking = palette.marking {
            spots(
                head, marking,
                at: [CGPoint(x: 30, y: 34), CGPoint(x: 68, y: 31), CGPoint(x: 74, y: 40), CGPoint(x: 44, y: 28)])
        }
        head.blush(at: CGPoint(x: 26, y: 55), palette.cheek)
        head.blush(at: CGPoint(x: 74, y: 55), palette.cheek)
        head.eye(at: CGPoint(x: 36, y: 46), pose: pose, color: palette.eye)
        head.eye(at: CGPoint(x: 64, y: 46), pose: pose, color: palette.eye)
        head.mouth(at: CGPoint(x: 50, y: 55), pose: pose, tone: skin, width: 12)
        if let bow = palette.bow, !regal {
            BowArt.draw(head, color: bow, at: CGPoint(x: 70, y: 26))
        }
    }

    /// A soft glow behind a legendary pet.
    private static func aura(_ ink: Ink, color: PetColor) {
        let glow = Gradient(colors: [
            color.mixed(with: .white, amount: 0.4).color.opacity(0.55), color.color.opacity(0),
        ])
        ink.context.fill(
            Path(ellipse: CGPoint(x: 50, y: 58), rx: 46, ry: 42),
            with: .radialGradient(glow, center: CGPoint(x: 50, y: 58), startRadius: 8, endRadius: 46))
    }

    /// A scalloped fin running over the top of the head.
    private static func crest(flutter: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 34, y: 30))
        let peaks: [(CGFloat, CGFloat)] = [(39, 12), (46, 9), (54, 9), (61, 12)]
        var x: CGFloat = 34
        for (peakX, peakY) in peaks {
            let next = peakX + 3.5
            path.addQuadCurve(to: CGPoint(x: next, y: 26), control: CGPoint(x: peakX + flutter * 0.2, y: peakY))
            x = next
        }
        path.addLine(to: CGPoint(x: max(x, 66), y: 30))
        path.closeSubpath()
        return path
    }

    private static func gem(_ ink: Ink, color: PetColor) {
        let diamond = Path(
            roundedPolygon: [
                CGPoint(x: 50, y: 25.5), CGPoint(x: 54.5, y: 30.5), CGPoint(x: 50, y: 35.5), CGPoint(x: 45.5, y: 30.5),
            ],
            radius: 1)
        ink.part(diamond, Tone(color), shaded: false, gloss: true)
    }

    private static var tail: Path {
        var path = Path()
        path.move(to: CGPoint(x: 63, y: 67))
        path.addQuadCurve(to: CGPoint(x: 95, y: 57), control: CGPoint(x: 82, y: 72))
        path.addQuadCurve(to: CGPoint(x: 64, y: 84), control: CGPoint(x: 90, y: 84))
        path.closeSubpath()
        return path
    }

    /// Fronds on the left side, each a capsule with little feathery bumps: three, or four
    /// longer flowing ones for the legendary.
    private static func gillFronds(flutter: Double, regal: Bool = false) -> Path {
        let anchor = CGPoint(x: 24, y: 39)
        var path = Path()
        let angles: [Double] = regal ? [-150, -172, 165, 140] : [-142, 178, 138]
        for (index, angle) in angles.enumerated() {
            let length = (index == 1 ? 21.0 : 19.0) * (regal ? 1.2 : 1)
            var frond = Path(roundedRect: CGRect(x: 0, y: -2.7, width: length, height: 5.4), cornerRadius: 2.7)
            // Feathery filaments along the top edge.
            for step in 0..<3 {
                frond.addEllipse(in: CGRect(x: 9 + Double(step) * 3.6, y: -5, width: 3.6, height: 3.6))
            }
            let swing = angle + flutter * (index == 1 ? 1 : 0.6)
            let turn = CGAffineTransform(rotationAngle: swing * .pi / 180)
            path.addPath(frond.applying(turn.concatenating(CGAffineTransform(translationX: anchor.x, y: anchor.y))))
        }
        return path
    }

    private static func spots(_ ink: Ink, _ color: PetColor, at points: [CGPoint]) {
        for point in points {
            ink.context.fill(Path(ellipse: point, rx: 2.2, ry: 1.8), with: .color(color.color.opacity(0.8)))
        }
    }
}
