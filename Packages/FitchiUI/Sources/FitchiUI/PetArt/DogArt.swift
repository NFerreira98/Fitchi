import SwiftUI

/// Round head, floppy ears, a cream muzzle and a waggy tail.
enum DogArt {
    static func draw(_ ink: Ink, palette: PetPalette, pose: PetPose) {
        let fur = Tone(palette.body)
        let cream = Tone(palette.belly)
        let ears = Tone(palette.accent)

        var tail = Path()
        tail.move(to: CGPoint(x: 64, y: 80))
        tail.addQuadCurve(to: CGPoint(x: 80, y: 62), control: CGPoint(x: 80, y: 78))
        ink.limb(tail.rotated(degrees: pose.tailAngle, around: CGPoint(x: 64, y: 80)), fur, width: 6.5)
        let body = Path(ellipse: CGPoint(x: 50, y: 77), rx: 19, ry: 14)
        ink.part(body, fur)
        if let marking = palette.marking, palette.pattern == .patches {
            Patches.draw(ink, marking, clippedTo: body, blobs: [(CGPoint(x: 62, y: 72), 7)])
        }
        ink.part(Path(ellipse: CGPoint(x: 50, y: 76), rx: 10, ry: 8), cream, shaded: false, outlined: false)
        ink.part(Path(ellipse: CGPoint(x: 40, y: 90), rx: 6.5, ry: 4), cream, shaded: false)
        ink.part(Path(ellipse: CGPoint(x: 60, y: 90), rx: 6.5, ry: 4), cream, shaded: false)

        var head = ink
        head.context.translateBy(x: 0, y: pose.headBob)
        let face = Path(ellipse: CGPoint(x: 50, y: 46), rx: 28, ry: 23)
        head.part(face, fur, gloss: true)
        if let marking = palette.marking, palette.pattern == .patches {
            Patches.draw(head, marking, clippedTo: face, blobs: [(CGPoint(x: 63, y: 43), 9)])
        }
        // Floppy ears hang over the sides of the head and swing with `earAngle`.
        let ear = Path(ellipse: CGPoint(x: 24, y: 44), rx: 8, ry: 15, degrees: 14)
        let pivot = CGPoint(x: 28, y: 30)
        head.part(ear.rotated(degrees: pose.earAngle, around: pivot), ears)
        head.part(ear.rotated(degrees: pose.earAngle, around: pivot).mirrored, ears)
        head.part(Path(ellipse: CGPoint(x: 50, y: 58), rx: 12, ry: 8.5), cream, shaded: false)
        head.blush(at: CGPoint(x: 31, y: 56), palette.cheek)
        head.blush(at: CGPoint(x: 69, y: 56), palette.cheek)
        head.eye(at: CGPoint(x: 39, y: 45), pose: pose, color: palette.eye)
        head.eye(at: CGPoint(x: 61, y: 45), pose: pose, color: palette.eye)
        let nose = Path(ellipse: CGPoint(x: 50, y: 54.5), rx: 4, ry: 2.8)
        head.part(nose, Tone(palette.eye), shaded: false, gloss: true, outlined: false)
        var mouth = Path()
        mouth.move(to: CGPoint(x: 50, y: 57))
        mouth.addLine(to: CGPoint(x: 50, y: 59))
        head.line(mouth, cream.line, width: 1.5)
        head.mouth(at: CGPoint(x: 50, y: 59.5), pose: pose, tone: cream, width: 8)
        if pose.mouthOpen <= 0.1, pose.smile > 0.5 {
            head.context.fill(
                Path(ellipse: CGPoint(x: 50, y: 63), rx: 2.6, ry: 2.2),
                with: .color(Color(red: 1, green: 0.5, blue: 0.6)))
        }
    }
}
