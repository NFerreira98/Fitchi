import FitchiCore
import SwiftUI

/// Little pictures drawn the way the pets are (outlined, cel-shaded, a touch of gloss), so the
/// care buttons, stat bars, thought bubbles and rewards belong to the same world as the pet.
/// Each draws in a 100×100 art space.
enum IconArt {
    static func draw(_ action: CareAction, _ ink: Ink) {
        switch action {
        case .feed: bowl(ink)
        case .play: ball(ink)
        case .wash: bubbles(ink)
        case .rest: moon(ink)
        }
    }

    static func draw(_ stat: Stat, _ ink: Ink) {
        switch stat {
        case .hunger: bowl(ink)
        case .happiness: heart(ink)
        case .energy: bolt(ink)
        case .cleanliness: drop(ink)
        }
    }

    static func gift(_ ink: Ink, lucky: Bool) {
        if lucky { coin(ink) } else { present(ink) }
    }

    private static func tone(_ hex: UInt32) -> Tone { Tone(PetColor(hex: hex)) }

    // MARK: - Care

    /// A red dish heaped with kibble.
    static func bowl(_ ink: Ink) {
        var dish = Path()
        dish.move(to: CGPoint(x: 14, y: 50))
        dish.addLine(to: CGPoint(x: 86, y: 50))
        dish.addQuadCurve(to: CGPoint(x: 70, y: 84), control: CGPoint(x: 86, y: 80))
        dish.addLine(to: CGPoint(x: 30, y: 84))
        dish.addQuadCurve(to: CGPoint(x: 14, y: 50), control: CGPoint(x: 14, y: 80))
        dish.closeSubpath()
        let kibble = tone(0xC98A4B)
        for (x, y, radius) in [(32.0, 44.0, 11.0), (68, 44, 11), (50, 40, 13), (40, 32, 9), (60, 32, 9), (50, 26, 8)] {
            ink.part(Path(ellipse: CGPoint(x: x, y: y), rx: radius, ry: radius * 0.8), kibble, shaded: false)
        }
        ink.part(dish, tone(0xFF6B6B), gloss: true)
        ink.part(Path(ellipse: CGPoint(x: 50, y: 50), rx: 36, ry: 6), tone(0xFF8A8A), shaded: false)
    }

    /// A tennis ball with its seam.
    static func ball(_ ink: Ink) {
        let center = CGPoint(x: 50, y: 52)
        ink.part(Path(ellipse: center, rx: 36, ry: 36), tone(0xD7F24B), gloss: true)
        for side in [-1.0, 1] {
            var seam = Path()
            seam.move(to: CGPoint(x: center.x + side * 30, y: center.y - 22))
            seam.addQuadCurve(
                to: CGPoint(x: center.x + side * 30, y: center.y + 22),
                control: CGPoint(x: center.x + side * 6, y: center.y))
            ink.line(seam, .white.opacity(0.9), width: 4)
        }
    }

    /// Three soap bubbles with glints.
    static func bubbles(_ ink: Ink) {
        let soap = tone(0xBFE6FF)
        for (x, y, radius) in [(38.0, 60.0, 26.0), (68, 36, 18), (72, 72, 11)] {
            ink.part(Path(ellipse: CGPoint(x: x, y: y), rx: radius, ry: radius), soap, shaded: false, gloss: true)
            ink.context.fill(
                Path(
                    ellipse: CGPoint(x: x + radius * 0.3, y: y + radius * 0.3), rx: radius * 0.28, ry: radius * 0.18,
                    degrees: -40),
                with: .color(.white.opacity(0.7)))
        }
    }

    /// A crescent moon with two little stars.
    static func moon(_ ink: Ink) {
        ink.part(
            crescent(center: CGPoint(x: 46, y: 52), radius: 36, bite: CGPoint(x: 64, y: 42), biteRadius: 30),
            tone(0xFFD54D), gloss: true)
        for (point, size) in [(CGPoint(x: 80, y: 22), 8.0), (CGPoint(x: 86, y: 58), 5.5)] {
            ink.context.fill(Sparkles.star(at: point, size: size), with: .color(PetColor(hex: 0xFFE89A).color))
        }
    }

    // MARK: - Stats

    static func heart(_ ink: Ink) {
        ink.part(heartPath(at: CGPoint(x: 50, y: 50), size: 30), tone(0xFF5C9A), gloss: true)
    }

    static func bolt(_ ink: Ink) {
        let shape = Path(
            roundedPolygon: [
                CGPoint(x: 60, y: 6), CGPoint(x: 26, y: 56), CGPoint(x: 48, y: 56), CGPoint(x: 40, y: 94),
                CGPoint(x: 76, y: 42), CGPoint(x: 54, y: 42),
            ], radius: 3)
        ink.part(shape, tone(0xFFD54D), gloss: true)
    }

    static func drop(_ ink: Ink) {
        var shape = Path()
        shape.move(to: CGPoint(x: 50, y: 8))
        shape.addCurve(to: CGPoint(x: 50, y: 92), control1: CGPoint(x: 90, y: 56), control2: CGPoint(x: 88, y: 92))
        shape.addCurve(to: CGPoint(x: 50, y: 8), control1: CGPoint(x: 12, y: 92), control2: CGPoint(x: 10, y: 56))
        shape.closeSubpath()
        ink.part(shape, tone(0x4FC3F7), gloss: true)
    }

    // MARK: - Gifts

    static func present(_ ink: Ink) {
        let box = tone(0xFF7BAC)
        ink.part(Path(roundedRect: CGRect(x: 20, y: 46, width: 60, height: 44), cornerRadius: 6), box)
        ink.part(Path(roundedRect: CGRect(x: 14, y: 34, width: 72, height: 18), cornerRadius: 5), tone(0xFF5C9A))
        ink.context.fill(Path(CGRect(x: 44, y: 36, width: 12, height: 54)), with: .color(PetColor(hex: 0xFFD54D).color))
        let ribbon = tone(0xFFD54D)
        for side in [-1.0, 1] {
            ink.part(
                Path(ellipse: CGPoint(x: 50 + side * 13, y: 24), rx: 13, ry: 8, degrees: side * -25), ribbon,
                shaded: false)
        }
        ink.part(Path(ellipse: CGPoint(x: 50, y: 28), rx: 6, ry: 6), ribbon, shaded: false)
    }

    static func coin(_ ink: Ink) {
        ink.part(Path(ellipse: CGPoint(x: 50, y: 50), rx: 36, ry: 36), tone(0xFFC93D), gloss: true)
        ink.line(Path(ellipse: CGPoint(x: 50, y: 50), rx: 27, ry: 27), PetColor(hex: 0xE5A91B).color, width: 3)
        ink.context.fill(
            Sparkles.star(at: CGPoint(x: 50, y: 50), size: 16), with: .color(PetColor(hex: 0xFFF2BF).color))
    }

    // MARK: - Shapes

    static func heartPath(at center: CGPoint, size: CGFloat) -> Path {
        var path = Path()
        let top = center.y - size * 0.35
        path.move(to: CGPoint(x: center.x, y: center.y + size * 0.95))
        path.addCurve(
            to: CGPoint(x: center.x - size, y: top),
            control1: CGPoint(x: center.x - size * 0.5, y: center.y + size * 0.5),
            control2: CGPoint(x: center.x - size, y: center.y + size * 0.2))
        path.addArc(
            center: CGPoint(x: center.x - size * 0.5, y: top), radius: size * 0.5, startAngle: .degrees(180),
            endAngle: .degrees(0), clockwise: false)
        path.addArc(
            center: CGPoint(x: center.x + size * 0.5, y: top), radius: size * 0.5, startAngle: .degrees(180),
            endAngle: .degrees(0), clockwise: false)
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y + size * 0.95),
            control1: CGPoint(x: center.x + size, y: center.y + size * 0.2),
            control2: CGPoint(x: center.x + size * 0.5, y: center.y + size * 0.5))
        path.closeSubpath()
        return path
    }

    /// A circle with a bite taken out of it by a second circle: a moon.
    static func crescent(center: CGPoint, radius: CGFloat, bite: CGPoint, biteRadius: CGFloat) -> Path {
        // Where the two circles cross.
        let acrossX = bite.x - center.x
        let acrossY = bite.y - center.y
        let distance = (acrossX * acrossX + acrossY * acrossY).squareRoot()
        let along = (radius * radius - biteRadius * biteRadius + distance * distance) / (2 * distance)
        let across = max(0, radius * radius - along * along).squareRoot()
        let mid = CGPoint(x: center.x + acrossX * along / distance, y: center.y + acrossY * along / distance)
        let first = CGPoint(x: mid.x + across * -acrossY / distance, y: mid.y + across * acrossX / distance)
        let second = CGPoint(x: mid.x - across * -acrossY / distance, y: mid.y - across * acrossX / distance)
        func angle(_ point: CGPoint, around pivot: CGPoint) -> Angle {
            .radians(atan2(point.y - pivot.y, point.x - pivot.x))
        }
        var path = Path()
        path.move(to: first)
        path.addArc(
            center: center, radius: radius, startAngle: angle(first, around: center),
            endAngle: angle(second, around: center), clockwise: false)
        path.addArc(
            center: bite, radius: biteRadius, startAngle: angle(second, around: bite),
            endAngle: angle(first, around: bite), clockwise: true)
        path.closeSubpath()
        return path
    }
}

/// A canvas that lays out the 100×100 art space in the view with a little room for outlines.
private struct ArtCanvas: View {
    let draw: (Ink) -> Void

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 108
            context.translateBy(x: (size.width - 100 * scale) / 2, y: (size.height - 100 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            draw(Ink(context: context))
        }
        .accessibilityHidden(true)
    }
}

/// The picture for a care action: bowl, ball, bubbles or moon.
public struct CareIcon: View {
    private let action: CareAction

    public init(_ action: CareAction) { self.action = action }

    public var body: some View { ArtCanvas { IconArt.draw(action, $0) } }
}

/// The picture for a stat: bowl, heart, bolt or drop.
public struct StatIcon: View {
    private let stat: Stat

    public init(_ stat: Stat) { self.stat = stat }

    public var body: some View { ArtCanvas { IconArt.draw(stat, $0) } }
}

/// A wrapped present, or a gold coin for a lucky find.
public struct GiftIcon: View {
    private let lucky: Bool

    public init(lucky: Bool) { self.lucky = lucky }

    public var body: some View { ArtCanvas { IconArt.gift($0, lucky: lucky) } }
}
