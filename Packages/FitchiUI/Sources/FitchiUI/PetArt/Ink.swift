import SwiftUI

/// The moment-to-moment body language of a pet. Animations drive these numbers; the painters
/// read them. Everything defaults to a calm, front-facing stand.
public struct PetPose: Hashable, Sendable {
    /// Vertical hop in art units (positive = up).
    public var lift: Double = 0
    /// Squash (positive) or stretch (negative) around the feet, roughly −0.3…0.3.
    public var squash: Double = 0
    /// Head dip from breathing, in art units.
    public var headBob: Double = 0
    /// 1 = eyes open, 0 = closed.
    public var eyesOpen: Double = 1
    /// Where the pupils look, −1…1 on each axis.
    public var lookX: Double = 0
    public var lookY: Double = 0
    /// Tail swing in degrees.
    public var tailAngle: Double = 0
    /// Ear / gill flutter in degrees.
    public var earAngle: Double = 0
    /// 0 = closed smile, 1 = open mouth (eating, laughing).
    public var mouthOpen: Double = 0

    public init() {}

    public static let standing = PetPose()
}

/// Drawing helpers in a 100×100 art space, ground line at y = 94.
/// Parts are drawn back to front; each part's outline overlaps whatever is behind it,
/// which gives the sticker-like separation between head, ears and body.
struct Ink {
    var context: GraphicsContext
    static let outline: CGFloat = 2.4
    static let ground: CGFloat = 94

    /// Fill with an outline, a cel-shade crescent at the bottom right and an optional gloss.
    func part(_ path: Path, _ tone: Tone, shaded: Bool = true, gloss: Bool = false, outlined: Bool = true) {
        if outlined {
            context.stroke(
                path, with: .color(tone.line), style: StrokeStyle(lineWidth: Self.outline * 2, lineJoin: .round))
        }
        guard shaded || gloss else {
            context.fill(path, with: .color(tone.base))
            return
        }
        context.drawLayer { layer in
            layer.clip(to: path)
            if shaded {
                layer.fill(path, with: .color(tone.shade))
                layer.fill(path.offsetBy(dx: -2.2, dy: -3), with: .color(tone.base))
            } else {
                layer.fill(path, with: .color(tone.base))
            }
            if gloss {
                let box = path.boundingRect
                let shine = CGRect(
                    x: box.minX + box.width * 0.2, y: box.minY + box.height * 0.12,
                    width: box.width * 0.26, height: box.height * 0.16
                )
                layer.fill(Path(ellipseIn: shine), with: .color(tone.light.opacity(0.75)))
            }
        }
    }

    /// A thick rounded stroke with an outline, for tails.
    func limb(_ path: Path, _ tone: Tone, width: CGFloat) {
        context.stroke(
            path, with: .color(tone.line), style: StrokeStyle(lineWidth: width + Self.outline * 2, lineCap: .round))
        context.stroke(path, with: .color(tone.base), style: StrokeStyle(lineWidth: width, lineCap: .round))
        context.stroke(
            path.offsetBy(dx: -0.8, dy: -1.1),
            with: .color(tone.light.opacity(0.5)),
            style: StrokeStyle(lineWidth: width * 0.3, lineCap: .round)
        )
    }

    func line(_ path: Path, _ color: Color, width: CGFloat = 1.8) {
        context.stroke(
            path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }

    func blush(at center: CGPoint, _ color: PetColor) {
        context.fill(Path(ellipse: center, rx: 5, ry: 3), with: .color(color.color.opacity(0.55)))
    }

    /// Big glossy eyes; they squeeze into a happy arc as they close.
    func eye(at center: CGPoint, pose: PetPose, color: PetColor) {
        let width: CGFloat = 7.5
        let height = 9.0 * max(pose.eyesOpen, 0)
        if pose.eyesOpen < 0.25 {
            var arc = Path()
            arc.move(to: CGPoint(x: center.x - width / 2, y: center.y + 1))
            arc.addQuadCurve(
                to: CGPoint(x: center.x + width / 2, y: center.y + 1), control: CGPoint(x: center.x, y: center.y - 3))
            line(arc, color.color, width: 2)
            return
        }
        let look = CGPoint(x: center.x + pose.lookX * 1.4, y: center.y + pose.lookY * 1.2)
        context.fill(Path(ellipse: look, rx: width / 2, ry: height / 2), with: .color(color.color))
        let white = Color.white
        context.fill(
            Path(ellipse: CGPoint(x: look.x - 1.2, y: look.y - height * 0.2), rx: 1.7, ry: 1.9 * pose.eyesOpen),
            with: .color(white))
        context.fill(
            Path(ellipse: CGPoint(x: look.x + 1.5, y: look.y + height * 0.22), rx: 0.8, ry: 0.8 * pose.eyesOpen),
            with: .color(white))
    }

    /// A small smile that opens into a round mouth.
    func mouth(at center: CGPoint, pose: PetPose, tone: Tone, width: CGFloat = 6) {
        if pose.mouthOpen > 0.1 {
            let open = Path(
                ellipse: CGPoint(x: center.x, y: center.y + 1), rx: width * 0.35, ry: 1 + 2.4 * pose.mouthOpen)
            context.fill(open, with: .color(Color(red: 0.55, green: 0.2, blue: 0.3)))
            context.stroke(open, with: .color(tone.line), lineWidth: 1.4)
            return
        }
        var smile = Path()
        smile.move(to: CGPoint(x: center.x - width / 2, y: center.y))
        smile.addQuadCurve(
            to: CGPoint(x: center.x + width / 2, y: center.y), control: CGPoint(x: center.x, y: center.y + 4))
        line(smile, tone.line)
    }
}

extension Path {
    init(ellipse center: CGPoint, rx: CGFloat, ry: CGFloat, degrees: Double = 0) {
        let oval = Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
        let turn = CGAffineTransform(rotationAngle: degrees * .pi / 180)
        self = oval.applying(turn.concatenating(CGAffineTransform(translationX: center.x, y: center.y)))
    }

    /// A polygon with every corner rounded off; good for soft ears.
    init(roundedPolygon points: [CGPoint], radius: CGFloat) {
        self.init()
        for index in points.indices {
            let previous = points[(index + points.count - 1) % points.count]
            let current = points[index]
            let next = points[(index + 1) % points.count]
            let entry = current.moved(toward: previous, by: radius)
            let exit = current.moved(toward: next, by: radius)
            if index == 0 { move(to: entry) } else { addLine(to: entry) }
            addQuadCurve(to: exit, control: current)
        }
        closeSubpath()
    }

    func rotated(degrees: Double, around pivot: CGPoint) -> Path {
        let toOrigin = CGAffineTransform(translationX: -pivot.x, y: -pivot.y)
        let turn = CGAffineTransform(rotationAngle: degrees * .pi / 180)
        let back = CGAffineTransform(translationX: pivot.x, y: pivot.y)
        return applying(toOrigin.concatenating(turn).concatenating(back))
    }

    /// Mirror across the vertical centre line of the art space.
    var mirrored: Path {
        applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 100, ty: 0))
    }
}

extension CGPoint {
    func moved(toward target: CGPoint, by distance: CGFloat) -> CGPoint {
        let deltaX = target.x - x
        let deltaY = target.y - y
        let length = max((deltaX * deltaX + deltaY * deltaY).squareRoot(), 0.001)
        let step = min(distance, length / 2) / length
        return CGPoint(x: x + deltaX * step, y: y + deltaY * step)
    }
}
