import SwiftUI

/// Tall floppy ears, a cotton tail, long feet and two little buck teeth.
/// Palette: `body` fur, `belly` muzzle/tummy/tail, `accent` inner ears, `marking` patches.
enum BunnyArt {
    static func draw(_ ink: Ink, palette: PetPalette, pose: PetPose) {
        let fur = Tone(palette.body)
        let fluff = Tone(palette.belly)
        let inner = Tone(palette.accent)

        // Cotton tail, bobbing with the tail swing.
        let tailCenter = CGPoint(x: 68 + pose.tailAngle * 0.12, y: 81)
        ink.part(Path(ellipse: tailCenter, rx: 7, ry: 6.5), fluff, gloss: true)
        let body = Path(ellipse: CGPoint(x: 50, y: 78), rx: 18, ry: 14)
        ink.part(body, fur)
        if let marking = palette.marking, palette.pattern == .patches {
            Patches.draw(ink, marking, clippedTo: body, blobs: [(CGPoint(x: 60, y: 72), 8)])
        }
        ink.part(Path(ellipse: CGPoint(x: 50, y: 80), rx: 10, ry: 8), fluff, shaded: false, outlined: false)
        // Long hind feet.
        ink.part(Path(ellipse: CGPoint(x: 38, y: 91), rx: 8.5, ry: 3.8), fluff, shaded: false)
        ink.part(Path(ellipse: CGPoint(x: 62, y: 91), rx: 8.5, ry: 3.8), fluff, shaded: false)

        var head = ink
        head.context.translateBy(x: 0, y: pose.headBob)
        // Ears stand behind the head and sway (outward) with `earAngle`.
        for flip in [false, true] {
            let pivot = CGPoint(x: 40, y: 34)
            let tilt = -14 - pose.earAngle * 1.4
            let outer = Path(ellipse: CGPoint(x: 39, y: 17), rx: 7, ry: 19).rotated(degrees: tilt, around: pivot)
            let core = Path(ellipse: CGPoint(x: 39, y: 18), rx: 3.4, ry: 13).rotated(degrees: tilt, around: pivot)
            head.part(flip ? outer.mirrored : outer, fur)
            head.part(flip ? core.mirrored : core, inner, shaded: false, outlined: false)
        }
        let face = Path(ellipse: CGPoint(x: 50, y: 49), rx: 26, ry: 21)
        head.part(face, fur, gloss: true)
        if let marking = palette.marking, palette.pattern == .patches {
            // A Dutch-style blaze: dark cheeks around a light middle.
            Patches.draw(
                head, marking, clippedTo: face, blobs: [(CGPoint(x: 30, y: 44), 13), (CGPoint(x: 70, y: 44), 13)])
        }
        head.part(Path(ellipse: CGPoint(x: 45.5, y: 58), rx: 6, ry: 4.6), fluff, shaded: false, outlined: false)
        head.part(Path(ellipse: CGPoint(x: 54.5, y: 58), rx: 6, ry: 4.6), fluff, shaded: false, outlined: false)
        head.blush(at: CGPoint(x: 30, y: 56), palette.cheek)
        head.blush(at: CGPoint(x: 70, y: 56), palette.cheek)
        head.eye(at: CGPoint(x: 39, y: 48), pose: pose, color: palette.eye)
        head.eye(at: CGPoint(x: 61, y: 48), pose: pose, color: palette.eye)
        let nose = Path(ellipse: CGPoint(x: 50, y: 54.5), rx: 2.6, ry: 1.9)
        head.context.fill(nose, with: .color(palette.accent.mixed(with: .lineInk, amount: 0.25).color))
        mouth(head, pose: pose, fur: fur)
        if let bow = palette.bow {
            BowArt.draw(head, color: bow, at: CGPoint(x: 66, y: 31))
        }
    }

    /// A "w" mouth with two buck teeth, or an open mouth or frown.
    private static func mouth(_ head: Ink, pose: PetPose, fur: Tone) {
        if pose.mouthOpen > 0.1 || pose.smile < 0.5 {
            head.mouth(at: CGPoint(x: 50, y: 59), pose: pose, tone: fur, width: 6)
        } else {
            // A "w" mouth with two buck teeth peeking out.
            let teeth = Path(roundedRect: CGRect(x: 48, y: 59.2, width: 4, height: 3.6), cornerRadius: 1)
            head.context.fill(teeth, with: .color(.white))
            head.context.stroke(teeth, with: .color(fur.line), lineWidth: 1)
            head.line(
                Path { path in
                    path.move(to: CGPoint(x: 50, y: 59.2))
                    path.addLine(to: CGPoint(x: 50, y: 62.6))
                }, fur.line, width: 0.8)
            var mouth = Path()
            mouth.move(to: CGPoint(x: 46, y: 58.6))
            mouth.addQuadCurve(to: CGPoint(x: 50, y: 58), control: CGPoint(x: 48, y: 60.6))
            mouth.addQuadCurve(to: CGPoint(x: 54, y: 58.6), control: CGPoint(x: 52, y: 60.6))
            head.line(mouth, fur.line, width: 1.4)
        }
    }
}
