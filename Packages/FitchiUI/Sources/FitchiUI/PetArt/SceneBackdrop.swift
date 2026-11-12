import SwiftUI

/// A background the pet stands in front of. Backdrops are unlockable on their own and work with
/// any pet; Core only knows the id.
public struct SceneBackdrop: View {
    /// Raw values are the shop item ids (`Catalog.defaultBackdropID` for the meadow).
    public enum Kind: String, CaseIterable, Sendable {
        case meadow = "backdrop-meadow"
        case pond = "backdrop-pond"
        case snowyHill = "backdrop-snowy-hill"
        case beach = "backdrop-beach"
        case starryNight = "backdrop-starry-night"
        case forest = "backdrop-forest"
        case bedroom = "backdrop-bedroom"
        case livingRoom = "backdrop-living-room"
        case kitchen = "backdrop-kitchen"

        /// Accepts shop ids ("backdrop-pond") and short names ("pond").
        public init(id: String) {
            self = Kind(rawValue: id) ?? Kind(rawValue: "backdrop-\(id)") ?? .meadow
        }
    }

    private let kind: Kind

    public init(_ kind: Kind) {
        self.kind = kind
    }

    public init(id: String) {
        kind = Kind(id: id)
    }

    public var body: some View {
        Canvas { context, size in
            // Width-based art space; the ground stretches to fill any extra height.
            let scale = size.width / 100
            context.scaleBy(x: scale, y: scale)
            let height = size.height / scale
            switch kind {
            case .meadow: Meadow.draw(context, height: height)
            case .pond: Pond.draw(context, height: height)
            case .snowyHill: SnowyHill.draw(context, height: height)
            case .beach: Beach.draw(context, height: height)
            case .starryNight: StarryNight.draw(context, height: height)
            case .forest: Forest.draw(context, height: height)
            case .bedroom: Bedroom.draw(context, height: height)
            case .livingRoom: LivingRoom.draw(context, height: height)
            case .kitchen: Kitchen.draw(context, height: height)
            }
        }
        .accessibilityHidden(true)
    }
}

enum Sky {
    static func draw(_ context: GraphicsContext, top: Color, bottom: Color, horizon: CGFloat) {
        let sky = Path(CGRect(x: 0, y: 0, width: 100, height: horizon + 2))
        context.fill(
            sky,
            with: .linearGradient(
                Gradient(colors: [top, bottom]), startPoint: .zero, endPoint: CGPoint(x: 0, y: horizon)))
        cloud(context, at: CGPoint(x: 22, y: 16), size: 1)
        cloud(context, at: CGPoint(x: 78, y: 26), size: 0.7)
    }

    static func cloud(_ context: GraphicsContext, at center: CGPoint, size: CGFloat) {
        var puff = Path()
        for (deltaX, deltaY, radius) in [(-7.0, 1.0, 5.0), (0, -2, 7), (8, 1, 5.5), (2, 3, 5)] {
            puff.addEllipse(
                in: CGRect(
                    x: center.x + (deltaX - radius) * size, y: center.y + (deltaY - radius) * size,
                    width: radius * 2 * size, height: radius * 2 * size
                ))
        }
        context.fill(puff, with: .color(.white.opacity(0.9)))
    }
}

private enum Meadow {
    static func draw(_ context: GraphicsContext, height: CGFloat) {
        let horizon: CGFloat = 56
        Sky.draw(
            context, top: Color(red: 0.55, green: 0.80, blue: 1), bottom: Color(red: 0.86, green: 0.95, blue: 1),
            horizon: horizon)
        var hills = Path()
        hills.move(to: CGPoint(x: 0, y: horizon + 2))
        hills.addQuadCurve(to: CGPoint(x: 55, y: horizon - 2), control: CGPoint(x: 25, y: horizon - 14))
        hills.addQuadCurve(to: CGPoint(x: 100, y: horizon), control: CGPoint(x: 80, y: horizon - 12))
        hills.addLine(to: CGPoint(x: 100, y: height))
        hills.addLine(to: CGPoint(x: 0, y: height))
        context.fill(hills, with: .color(Color(red: 0.55, green: 0.80, blue: 0.50)))
        let field = Path(CGRect(x: 0, y: horizon + 6, width: 100, height: height))
        context.fill(
            field,
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.62, green: 0.87, blue: 0.48), Color(red: 0.48, green: 0.78, blue: 0.40)]
                ),
                startPoint: CGPoint(x: 0, y: horizon + 6), endPoint: CGPoint(x: 0, y: height)
            ))
        Flora.tufts(
            context, rows: [horizon + 12, horizon + 24, horizon + 38], color: Color(red: 0.40, green: 0.68, blue: 0.34))
        Flora.flowers(
            context,
            at: [CGPoint(x: 10, y: horizon + 20), CGPoint(x: 88, y: horizon + 16), CGPoint(x: 82, y: horizon + 34)])
    }
}

private enum Pond {
    static func draw(_ context: GraphicsContext, height: CGFloat) {
        let horizon: CGFloat = 50
        Sky.draw(
            context, top: Color(red: 1, green: 0.78, blue: 0.70), bottom: Color(red: 1, green: 0.93, blue: 0.84),
            horizon: horizon)
        let bank = Path(CGRect(x: 0, y: horizon, width: 100, height: height))
        context.fill(bank, with: .color(Color(red: 0.56, green: 0.80, blue: 0.52)))
        let water = Path(ellipse: CGPoint(x: 50, y: horizon + 16), rx: 58, ry: 14)
        context.fill(
            water,
            with: .linearGradient(
                Gradient(colors: [Color(red: 0.55, green: 0.85, blue: 0.95), Color(red: 0.36, green: 0.70, blue: 0.88)]
                ),
                startPoint: CGPoint(x: 0, y: horizon + 2), endPoint: CGPoint(x: 0, y: horizon + 30)
            ))
        context.stroke(water, with: .color(Color(red: 0.42, green: 0.66, blue: 0.40)), lineWidth: 1.6)
        for (center, width) in [(CGPoint(x: 30, y: horizon + 11), 9.0), (CGPoint(x: 68, y: horizon + 20), 12)] {
            var ripple = Path()
            ripple.move(to: CGPoint(x: center.x - width / 2, y: center.y))
            ripple.addQuadCurve(
                to: CGPoint(x: center.x + width / 2, y: center.y), control: CGPoint(x: center.x, y: center.y - 1.5))
            context.stroke(ripple, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
        lilyPad(context, at: CGPoint(x: 16, y: horizon + 18), size: 6)
        lilyPad(context, at: CGPoint(x: 84, y: horizon + 10), size: 5)
        reeds(context, baseX: 92, baseY: horizon + 6)
        reeds(context, baseX: 6, baseY: horizon + 4)
        Flora.tufts(context, rows: [horizon + 36, horizon + 46], color: Color(red: 0.42, green: 0.68, blue: 0.38))
    }

    static func lilyPad(_ context: GraphicsContext, at center: CGPoint, size: CGFloat) {
        var pad = Path()
        pad.addArc(center: center, radius: size, startAngle: .degrees(20), endAngle: .degrees(340), clockwise: false)
        pad.addLine(to: center)
        pad.closeSubpath()
        let squashed = pad.applying(
            CGAffineTransform(translationX: -center.x, y: -center.y)
                .concatenating(CGAffineTransform(scaleX: 1, y: 0.45))
                .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        )
        context.fill(squashed, with: .color(Color(red: 0.36, green: 0.72, blue: 0.40)))
        context.fill(
            Path(ellipse: CGPoint(x: center.x - size * 0.2, y: center.y - 1.5), rx: 1.6, ry: 1.3),
            with: .color(Color(red: 1, green: 0.7, blue: 0.8)))
    }

    static func reeds(_ context: GraphicsContext, baseX: CGFloat, baseY: CGFloat) {
        for (offset, tall) in [(-2.5, 16.0), (0, 22), (2.5, 14)] {
            var stem = Path()
            stem.move(to: CGPoint(x: baseX + offset, y: baseY))
            stem.addQuadCurve(
                to: CGPoint(x: baseX + offset * 1.6, y: baseY - tall),
                control: CGPoint(x: baseX + offset, y: baseY - tall / 2))
            context.stroke(
                stem, with: .color(Color(red: 0.36, green: 0.60, blue: 0.32)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            if tall > 15 {
                let head = Path(
                    roundedRect: CGRect(x: baseX + offset * 1.6 - 1.3, y: baseY - tall, width: 2.6, height: 6),
                    cornerRadius: 1.3)
                context.fill(head, with: .color(Color(red: 0.55, green: 0.36, blue: 0.24)))
            }
        }
    }
}

enum Flora {
    static func tufts(_ context: GraphicsContext, rows: [CGFloat], color: Color) {
        for (row, baseY) in rows.enumerated() {
            for column in 0..<6 {
                let x = CGFloat(column) * 18 + (row.isMultiple(of: 2) ? 6 : 14)
                var tuft = Path()
                tuft.move(to: CGPoint(x: x - 2, y: baseY))
                tuft.addLine(to: CGPoint(x: x - 1, y: baseY - 2.5))
                tuft.move(to: CGPoint(x: x, y: baseY))
                tuft.addLine(to: CGPoint(x: x + 0.5, y: baseY - 3.5))
                tuft.move(to: CGPoint(x: x + 2, y: baseY))
                tuft.addLine(to: CGPoint(x: x + 2.5, y: baseY - 2.2))
                context.stroke(tuft, with: .color(color), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
            }
        }
    }

    static func flowers(_ context: GraphicsContext, at points: [CGPoint]) {
        let petals = [Color(red: 1, green: 0.75, blue: 0.85), Color.white, Color(red: 1, green: 0.85, blue: 0.4)]
        for (index, center) in points.enumerated() {
            for petal in 0..<5 {
                let angle = Double(petal) / 5 * 2 * .pi
                let spot = CGPoint(x: center.x + cos(angle) * 1.6, y: center.y + sin(angle) * 1.6)
                context.fill(Path(ellipse: spot, rx: 1.3, ry: 1.3), with: .color(petals[index % petals.count]))
            }
            context.fill(Path(ellipse: center, rx: 0.9, ry: 0.9), with: .color(Color(red: 1, green: 0.8, blue: 0.3)))
        }
    }
}
