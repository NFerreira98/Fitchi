import SwiftUI

/// A soft brown body, a wide duck bill, a flat beaver tail and webbed feet.
/// Palette: `body` fur, `belly` tummy, `accent` bill and feet, `marking` tail cross-hatching.
enum PlatypusArt {
    static func draw(_ ink: Ink, palette: PetPalette, pose: PetPose) {
        let fur = Tone(palette.body)
        let tummy = Tone(palette.belly)
        let bill = Tone(palette.accent)
        let tailTone = Tone(palette.marking ?? palette.body.mixed(with: .shadowInk, amount: 0.25))

        // Flat paddle tail with a cross-hatched texture.
        let pivot = CGPoint(x: 64, y: 84)
        let tail = Path(ellipse: CGPoint(x: 77, y: 83), rx: 15, ry: 7.5, degrees: -18)
            .rotated(degrees: pose.tailAngle * 0.6, around: pivot)
        ink.part(tail, tailTone)
        ink.context.drawLayer { layer in
            layer.clip(to: tail)
            for step in 0..<5 {
                let x = 68 + Double(step) * 4.5
                var hatch = Path()
                hatch.move(to: CGPoint(x: x, y: 74))
                hatch.addLine(to: CGPoint(x: x - 4, y: 92))
                layer.stroke(
                    hatch.rotated(degrees: pose.tailAngle * 0.6, around: pivot),
                    with: .color(tailTone.line.opacity(0.35)), lineWidth: 1)
            }
        }
        ink.part(Path(ellipse: CGPoint(x: 50, y: 78), rx: 21, ry: 14), fur)
        ink.part(Path(ellipse: CGPoint(x: 50, y: 81), rx: 12, ry: 7.5), tummy, shaded: false, outlined: false)
        for center in [CGPoint(x: 37, y: 91), CGPoint(x: 63, y: 91)] {
            webbedFoot(ink, at: center, tone: bill)
        }

        var head = ink
        head.context.translateBy(x: 0, y: pose.headBob)
        let face = Path(ellipse: CGPoint(x: 50, y: 48), rx: 25, ry: 20)
        head.part(face, fur, gloss: true)
        head.blush(at: CGPoint(x: 31, y: 52), palette.cheek)
        head.blush(at: CGPoint(x: 69, y: 52), palette.cheek)
        head.eye(at: CGPoint(x: 39, y: 44), pose: pose, color: palette.eye)
        head.eye(at: CGPoint(x: 61, y: 44), pose: pose, color: palette.eye)
        duckBill(head, tone: bill, pose: pose)
        if let bow = palette.bow {
            BowArt.draw(head, color: bow, at: CGPoint(x: 66, y: 31))
        }
    }

    /// A wide rounded bill with nostrils; it parts when the platypus eats or laughs.
    private static func duckBill(_ ink: Ink, tone: Tone, pose: PetPose) {
        let open = min(max(pose.mouthOpen, 0), 1) * 4
        if open > 0.4 {
            ink.part(Path(ellipse: CGPoint(x: 50, y: 64 + open), rx: 13, ry: 4.5), tone, shaded: false)
        }
        let upper = Path(roundedRect: CGRect(x: 33, y: 54, width: 34, height: 12), cornerRadius: 6)
        ink.part(upper, tone, gloss: true)
        for x in [46.0, 54.0] {
            ink.context.fill(Path(ellipse: CGPoint(x: x, y: 57.5), rx: 1.2, ry: 0.8), with: .color(tone.line))
        }
        if open <= 0.4 {
            // The bill's smile (or frown) line.
            var line = Path()
            line.move(to: CGPoint(x: 38, y: 61.5))
            line.addQuadCurve(to: CGPoint(x: 62, y: 61.5), control: CGPoint(x: 50, y: 61.5 + 3 * pose.smile))
            ink.line(line, tone.line, width: 1.3)
        }
    }

    private static func webbedFoot(_ ink: Ink, at center: CGPoint, tone: Tone) {
        var foot = Path(ellipse: center, rx: 7.5, ry: 3.6)
        for offset in [-4.5, 0, 4.5] {
            foot.addEllipse(in: CGRect(x: center.x + offset - 2, y: center.y + 0.5, width: 4, height: 4))
        }
        ink.part(foot, tone, shaded: false)
    }
}
