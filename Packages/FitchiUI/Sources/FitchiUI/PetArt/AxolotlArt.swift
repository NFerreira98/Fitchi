import SwiftUI

/// Wide smiley head, feathery gill fronds, a curled fin tail.
enum AxolotlArt {
    static func draw(_ ink: Ink, palette: PetPalette, pose: PetPose) {
        let skin = Tone(palette.body)
        let belly = Tone(palette.belly)
        let gills = Tone(palette.accent)

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
        head.part(gillFronds(flutter: flutter), gills, gloss: true)
        head.part(gillFronds(flutter: flutter).mirrored, gills, gloss: true)
        head.part(Path(ellipse: CGPoint(x: 50, y: 46), rx: 33, ry: 24), skin, gloss: true)
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
    }

    private static var tail: Path {
        var path = Path()
        path.move(to: CGPoint(x: 63, y: 67))
        path.addQuadCurve(to: CGPoint(x: 95, y: 57), control: CGPoint(x: 82, y: 72))
        path.addQuadCurve(to: CGPoint(x: 64, y: 84), control: CGPoint(x: 90, y: 84))
        path.closeSubpath()
        return path
    }

    /// Three fronds on the left side, each a capsule with little feathery bumps.
    private static func gillFronds(flutter: Double) -> Path {
        let anchor = CGPoint(x: 24, y: 39)
        var path = Path()
        for (index, angle) in [-142.0, 178, 138].enumerated() {
            let length = index == 1 ? 21.0 : 19.0
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
