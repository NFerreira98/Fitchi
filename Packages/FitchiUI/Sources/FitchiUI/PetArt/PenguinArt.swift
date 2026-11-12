import SwiftUI

/// One round body with a white face and tummy, flapping flippers, an orange beak and feet.
/// Palette: `body` back, `belly` face/tummy, `accent` beak and feet, `marking` crest tufts
/// (`stripes`, rockhopper) or ear patches (`patches`, emperor).
enum PenguinArt {
    static func draw(_ ink: Ink, palette: PetPalette, pose: PetPose) {
        let back = Tone(palette.body)
        let white = Tone(palette.belly)
        let orange = Tone(palette.accent)

        // Little tail tip and feet.
        let tail = Path(
            roundedPolygon: [CGPoint(x: 64, y: 82), CGPoint(x: 76, y: 92), CGPoint(x: 62, y: 91)], radius: 2.5)
        ink.part(tail.rotated(degrees: pose.tailAngle * 0.5, around: CGPoint(x: 64, y: 86)), back, shaded: false)
        ink.part(Path(ellipse: CGPoint(x: 40, y: 92), rx: 7.5, ry: 3.6, degrees: -8), orange, shaded: false)
        ink.part(Path(ellipse: CGPoint(x: 60, y: 92), rx: 7.5, ry: 3.6, degrees: 8), orange, shaded: false)

        // Flippers flap with `earAngle` (pinned at the shoulders).
        for flip in [false, true] {
            let flipper = Path(ellipse: CGPoint(x: 24, y: 68), rx: 6, ry: 15, degrees: 18)
                .rotated(degrees: -pose.earAngle * 2.2, around: CGPoint(x: 28, y: 56))
            ink.part(flip ? flipper.mirrored : flipper, back)
        }

        // The body and head are one shape; the face features bob on their own.
        let body = Path(ellipse: CGPoint(x: 50, y: 61), rx: 26, ry: 32)
        ink.part(body, back, gloss: true)
        ink.context.drawLayer { layer in
            layer.clip(to: body)
            layer.fill(Path(ellipse: CGPoint(x: 50, y: 74), rx: 18, ry: 21), with: .color(white.base))
            layer.fill(Path(ellipse: CGPoint(x: 41, y: 50 + pose.headBob), rx: 11, ry: 11), with: .color(white.base))
            layer.fill(Path(ellipse: CGPoint(x: 59, y: 50 + pose.headBob), rx: 11, ry: 11), with: .color(white.base))
            layer.fill(Path(ellipse: CGPoint(x: 50, y: 60), rx: 14, ry: 8), with: .color(white.base))
        }

        var head = ink
        head.context.translateBy(x: 0, y: pose.headBob)
        if let marking = palette.marking { markings(head, marking, pattern: palette.pattern, body: body) }
        head.blush(at: CGPoint(x: 34, y: 57), palette.cheek)
        head.blush(at: CGPoint(x: 66, y: 57), palette.cheek)
        head.eye(at: CGPoint(x: 41, y: 49), pose: pose, color: palette.eye)
        head.eye(at: CGPoint(x: 59, y: 49), pose: pose, color: palette.eye)
        beak(head, orange: orange, pose: pose)
        if let bow = palette.bow {
            BowArt.draw(head, color: bow, at: CGPoint(x: 64, y: 33))
        }
    }

    /// Rockhopper crest tufts (`stripes`) or emperor ear patches (anything else).
    private static func markings(_ head: Ink, _ marking: PetColor, pattern: PetPalette.Pattern, body: Path) {
        switch pattern {
        case .stripes:
            // Rockhopper crest: spiky tufts sweeping back from the brows.
            for flip in [false, true] {
                let tuft = Path(
                    roundedPolygon: [
                        CGPoint(x: 33, y: 41), CGPoint(x: 20, y: 30), CGPoint(x: 27, y: 37), CGPoint(x: 18, y: 38),
                    ],
                    radius: 1.2)
                head.part(flip ? tuft.mirrored : tuft, Tone(marking), shaded: false)
            }
        default:
            // Emperor: warm patches behind the face.
            head.context.drawLayer { layer in
                layer.clip(to: body)
                for point in [CGPoint(x: 27, y: 52), CGPoint(x: 73, y: 52)] {
                    layer.fill(Path(ellipse: point, rx: 5, ry: 8), with: .color(marking.color))
                }
            }
        }
    }

    /// A small rounded beak that opens when eating or laughing.
    private static func beak(_ ink: Ink, orange: Tone, pose: PetPose) {
        let open = min(max(pose.mouthOpen, 0), 1) * 3.5
        let top = Path(
            roundedPolygon: [CGPoint(x: 44.5, y: 54), CGPoint(x: 55.5, y: 54), CGPoint(x: 50, y: 59)], radius: 1.6)
        if open > 0.3 {
            let bottom = Path(
                roundedPolygon: [
                    CGPoint(x: 46, y: 57 + open), CGPoint(x: 54, y: 57 + open), CGPoint(x: 50, y: 60.5 + open),
                ],
                radius: 1.4)
            ink.part(bottom, orange, shaded: false)
        }
        ink.part(top, orange, shaded: false, gloss: true)
        if pose.smile < 0 {
            // A downturned beak line for a sad penguin.
            var line = Path()
            line.move(to: CGPoint(x: 46.5, y: 57.5))
            line.addQuadCurve(to: CGPoint(x: 53.5, y: 57.5), control: CGPoint(x: 50, y: 55.5))
            ink.line(line, orange.line, width: 1.2)
        }
    }
}
