import SwiftUI

/// Rusty fur, a white face mask with tear marks, dark legs and a big ringed tail.
/// Palette: `body` fur, `belly` dark legs/tummy, `accent` white mask and ear rims,
/// `marking` tail rings and tear marks.
enum RedPandaArt {
    static func draw(_ ink: Ink, palette: PetPalette, pose: PetPose) {
        let fur = Tone(palette.body)
        let dark = Tone(palette.belly)
        let mask = Tone(palette.accent)
        let rings = Tone(palette.marking ?? palette.body.mixed(with: .shadowInk, amount: 0.35))

        tail(ink, fur: fur, rings: rings, swing: pose.tailAngle)
        ink.part(Path(ellipse: CGPoint(x: 50, y: 78), rx: 18, ry: 14), fur)
        ink.part(Path(ellipse: CGPoint(x: 50, y: 82), rx: 10, ry: 7), dark, shaded: false, outlined: false)
        // Dark stocky legs.
        ink.part(Path(ellipse: CGPoint(x: 40, y: 89), rx: 6.5, ry: 5), dark)
        ink.part(Path(ellipse: CGPoint(x: 60, y: 89), rx: 6.5, ry: 5), dark)

        var head = ink
        head.context.translateBy(x: 0, y: pose.headBob)
        for flip in [false, true] {
            let tilt = flip ? -pose.earAngle : pose.earAngle
            let pivot = CGPoint(x: 32, y: 34)
            let ear = Path(
                roundedPolygon: [CGPoint(x: 20, y: 38), CGPoint(x: 24, y: 15), CGPoint(x: 42, y: 26)], radius: 6
            )
            .rotated(degrees: tilt, around: pivot)
            let rim = Path(
                roundedPolygon: [CGPoint(x: 25, y: 33), CGPoint(x: 27, y: 20), CGPoint(x: 37, y: 27)], radius: 3
            )
            .rotated(degrees: tilt, around: pivot)
            head.part(flip ? ear.mirrored : ear, fur)
            head.part(flip ? rim.mirrored : rim, mask, shaded: false, outlined: false)
        }
        let face = Path(ellipse: CGPoint(x: 50, y: 48), rx: 29, ry: 22)
        head.part(face, fur, gloss: true)
        maskMarkings(head, face: face, mask: mask, rings: rings)
        head.blush(at: CGPoint(x: 29, y: 59), palette.cheek)
        head.blush(at: CGPoint(x: 71, y: 59), palette.cheek)
        head.eye(at: CGPoint(x: 38, y: 47), pose: pose, color: palette.eye)
        head.eye(at: CGPoint(x: 62, y: 47), pose: pose, color: palette.eye)
        let nose = Path(ellipse: CGPoint(x: 50, y: 55), rx: 3.6, ry: 2.6)
        head.part(nose, Tone(palette.eye), shaded: false, gloss: true, outlined: false)
        head.mouth(at: CGPoint(x: 50, y: 59.5), pose: pose, tone: mask, width: 7)
        if let bow = palette.bow {
            BowArt.draw(head, color: bow, at: CGPoint(x: 68, y: 28))
        }
    }

    /// The white mask (brows, cheeks, muzzle) and the tear marks running down from the eyes.
    private static func maskMarkings(_ head: Ink, face: Path, mask: Tone, rings: Tone) {
        head.context.drawLayer { layer in
            layer.clip(to: face)
            // Brows, cheeks and muzzle: the classic white mask.
            for point in [CGPoint(x: 37, y: 37), CGPoint(x: 63, y: 37)] {
                layer.fill(
                    Path(ellipse: point, rx: 5.5, ry: 3.4, degrees: point.x < 50 ? -12 : 12), with: .color(mask.base))
            }
            layer.fill(Path(ellipse: CGPoint(x: 50, y: 60), rx: 17, ry: 10), with: .color(mask.base))
            layer.fill(Path(ellipse: CGPoint(x: 25, y: 55), rx: 7, ry: 6), with: .color(mask.base))
            layer.fill(Path(ellipse: CGPoint(x: 75, y: 55), rx: 7, ry: 6), with: .color(mask.base))
        }
        // Tear marks running from the eyes down the cheeks.
        for flip in [false, true] {
            var tear = Path()
            tear.move(to: CGPoint(x: 37, y: 51))
            tear.addQuadCurve(to: CGPoint(x: 36, y: 63), control: CGPoint(x: 33, y: 57))
            head.line(flip ? tear.mirrored : tear, rings.base, width: 3.2)
        }
    }

    /// A fluffy tail of overlapping puffs in alternating colours, curling up behind the body.
    private static func tail(_ ink: Ink, fur: Tone, rings: Tone, swing: Double) {
        let start = CGPoint(x: 62, y: 84)
        let control = CGPoint(x: 92, y: 86)
        let end = CGPoint(x: 84, y: 52)
        let count = 7
        for index in (0..<count).reversed() {
            let along = Double(index) / Double(count - 1)
            let point = CGPoint(
                x: (1 - along) * (1 - along) * start.x + 2 * (1 - along) * along * control.x + along * along * end.x,
                y: (1 - along) * (1 - along) * start.y + 2 * (1 - along) * along * control.y + along * along * end.y)
            let radius = 7.5 - along * 1.5
            let puff = Path(ellipse: point, rx: radius, ry: radius).rotated(degrees: swing, around: start)
            ink.part(puff, index.isMultiple(of: 2) ? fur : rings, shaded: index == count - 1)
        }
    }
}
