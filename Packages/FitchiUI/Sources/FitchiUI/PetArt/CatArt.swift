import SwiftUI

/// Round head, soft pointed ears, a white muzzle and a curling tail.
enum CatArt {
    static func draw(_ ink: Ink, palette: PetPalette, pose: PetPose) {
        let fur = Tone(palette.body)
        let white = Tone(palette.belly)
        let pink = Tone(palette.accent)

        var tail = Path()
        tail.move(to: CGPoint(x: 62, y: 84))
        tail.addCurve(to: CGPoint(x: 82, y: 56), control1: CGPoint(x: 84, y: 88), control2: CGPoint(x: 92, y: 66))
        ink.limb(tail.rotated(degrees: pose.tailAngle, around: CGPoint(x: 62, y: 84)), fur, width: 7)
        ink.part(Path(ellipse: CGPoint(x: 50, y: 77), rx: 18, ry: 14), fur)
        ink.part(Path(ellipse: CGPoint(x: 50, y: 75), rx: 9, ry: 8), white, shaded: false, outlined: false)
        ink.part(Path(ellipse: CGPoint(x: 40, y: 90), rx: 6, ry: 4), white, shaded: false)
        ink.part(Path(ellipse: CGPoint(x: 60, y: 90), rx: 6, ry: 4), white, shaded: false)

        var head = ink
        head.context.translateBy(x: 0, y: pose.headBob)
        let ear = Path(
            roundedPolygon: [CGPoint(x: 23, y: 40), CGPoint(x: 28, y: 11), CGPoint(x: 48, y: 27)], radius: 5)
        let innerEar = Path(
            roundedPolygon: [CGPoint(x: 28, y: 34), CGPoint(x: 30, y: 18), CGPoint(x: 41, y: 27)], radius: 3)
        for flip in [false, true] {
            let tilt = flip ? -pose.earAngle : pose.earAngle
            let pivot = CGPoint(x: 34, y: 32)
            let outer = ear.rotated(degrees: tilt, around: pivot)
            let inner = innerEar.rotated(degrees: tilt, around: pivot)
            head.part(flip ? outer.mirrored : outer, fur)
            head.part(flip ? inner.mirrored : inner, pink, shaded: false, outlined: false)
        }
        let face = Path(ellipse: CGPoint(x: 50, y: 47), rx: 29, ry: 23)
        head.part(face, fur, gloss: true)
        if let marking = palette.marking {
            switch palette.pattern {
            case .patches:
                Patches.draw(
                    head, marking, clippedTo: face, blobs: [(CGPoint(x: 30, y: 36), 12), (CGPoint(x: 70, y: 30), 9)])
            default:
                stripes(head, marking)
            }
        }
        head.part(Path(ellipse: CGPoint(x: 44.5, y: 58), rx: 6.5, ry: 5), white, shaded: false, outlined: false)
        head.part(Path(ellipse: CGPoint(x: 55.5, y: 58), rx: 6.5, ry: 5), white, shaded: false, outlined: false)
        whiskers(head, fur.line)
        head.blush(at: CGPoint(x: 29, y: 56), palette.cheek)
        head.blush(at: CGPoint(x: 71, y: 56), palette.cheek)
        head.eye(at: CGPoint(x: 38, y: 47), pose: pose, color: palette.eye)
        head.eye(at: CGPoint(x: 62, y: 47), pose: pose, color: palette.eye)
        let nose = Path(
            roundedPolygon: [CGPoint(x: 47, y: 53), CGPoint(x: 53, y: 53), CGPoint(x: 50, y: 57)], radius: 1.2)
        head.context.fill(nose, with: .color(palette.cheek.mixed(with: .lineInk, amount: 0.15).color))
        catMouth(head, pose: pose, tone: fur)
        if let bow = palette.bow {
            BowArt.draw(head, color: bow, at: CGPoint(x: 70, y: 27))
        }
    }

    private static func stripes(_ ink: Ink, _ color: PetColor) {
        for (offset, length) in [(-6.0, 6.0), (0, 8), (6, 6)] {
            let mark = Path(roundedRect: CGRect(x: 48.5 + offset, y: 24.5, width: 3, height: length), cornerRadius: 1.5)
            ink.context.fill(mark, with: .color(color.color))
        }
        for side in [false, true] {
            var cheek = Path()
            cheek.move(to: CGPoint(x: 22, y: 46))
            cheek.addLine(to: CGPoint(x: 28, y: 47))
            cheek.move(to: CGPoint(x: 22.5, y: 51))
            cheek.addLine(to: CGPoint(x: 27.5, y: 51))
            ink.line(side ? cheek.mirrored : cheek, color.color, width: 2.4)
        }
    }

    private static func whiskers(_ ink: Ink, _ color: Color) {
        var left = Path()
        left.move(to: CGPoint(x: 36, y: 58))
        left.addLine(to: CGPoint(x: 23, y: 56))
        left.move(to: CGPoint(x: 36, y: 61))
        left.addLine(to: CGPoint(x: 24, y: 63))
        ink.line(left, color.opacity(0.6), width: 1.1)
        ink.line(left.mirrored, color.opacity(0.6), width: 1.1)
    }

    /// The little "w" under the nose, or an open mouth or frown.
    private static func catMouth(_ ink: Ink, pose: PetPose, tone: Tone) {
        if pose.mouthOpen > 0.1 || pose.smile < 0.5 {
            ink.mouth(at: CGPoint(x: 50, y: 59), pose: pose, tone: tone)
            return
        }
        var mouth = Path()
        mouth.move(to: CGPoint(x: 46, y: 58.5))
        mouth.addQuadCurve(to: CGPoint(x: 50, y: 58), control: CGPoint(x: 48, y: 61))
        mouth.addQuadCurve(to: CGPoint(x: 54, y: 58.5), control: CGPoint(x: 52, y: 61))
        ink.line(mouth, tone.line, width: 1.5)
    }
}

/// Soft colour patches clipped inside a body part (calico, spotted dogs).
enum Patches {
    static func draw(_ ink: Ink, _ color: PetColor, clippedTo shape: Path, blobs: [(CGPoint, CGFloat)]) {
        ink.context.drawLayer { layer in
            layer.clip(to: shape)
            for (center, radius) in blobs {
                layer.fill(Path(ellipse: center, rx: radius, ry: radius * 0.85, degrees: 20), with: .color(color.color))
            }
        }
    }
}

/// A ribbon bow; any species can wear one.
enum BowArt {
    static func draw(_ ink: Ink, color: PetColor, at center: CGPoint) {
        let tone = Tone(color)
        let left = Path(
            roundedPolygon: [
                center, CGPoint(x: center.x - 10, y: center.y - 6), CGPoint(x: center.x - 9, y: center.y + 7),
            ], radius: 2.5)
        let right = Path(
            roundedPolygon: [
                center, CGPoint(x: center.x + 10, y: center.y - 6), CGPoint(x: center.x + 9, y: center.y + 7),
            ], radius: 2.5)
        ink.part(left, tone)
        ink.part(right, tone)
        ink.part(Path(ellipse: center, rx: 3.4, ry: 3.4), tone, shaded: false, gloss: true)
    }
}
