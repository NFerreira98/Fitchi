import FitchiCore
import SwiftUI

// The meadow (the free default) and the lily pond, plus the grass and flowers every green scene
// shares. Same conventions as the other outdoor scenes.

enum Meadow {
    static func draw(_ context: GraphicsContext, height: CGFloat, world: SceneWorld) {
        let horizon: CGFloat = 56
        Sky.draw(
            context, top: Color(red: 0.55, green: 0.80, blue: 1), bottom: Color(red: 0.86, green: 0.95, blue: 1),
            horizon: horizon, world: world)
        Distance.draw(
            context, horizon: horizon, style: .hills,
            tint: world.greenery(Color(red: 0.55, green: 0.80, blue: 0.50)).mix(
                with: Color(red: 0.86, green: 0.95, blue: 1), by: 0.5),
            world: world)
        var hills = Path()
        hills.move(to: CGPoint(x: 0, y: horizon + 2))
        hills.addQuadCurve(to: CGPoint(x: 55, y: horizon - 2), control: CGPoint(x: 25, y: horizon - 14))
        hills.addQuadCurve(to: CGPoint(x: 100, y: horizon), control: CGPoint(x: 80, y: horizon - 12))
        hills.addLine(to: CGPoint(x: 100, y: height))
        hills.addLine(to: CGPoint(x: 0, y: height))
        context.fill(hills, with: .color(world.greenery(Color(red: 0.55, green: 0.80, blue: 0.50))))
        let field = Path(CGRect(x: 0, y: horizon + 6, width: 100, height: height))
        context.fill(
            field,
            with: .linearGradient(
                Gradient(colors: [
                    world.greenery(Color(red: 0.62, green: 0.87, blue: 0.48)),
                    world.greenery(Color(red: 0.48, green: 0.78, blue: 0.40)),
                ]),
                startPoint: CGPoint(x: 0, y: horizon + 6), endPoint: CGPoint(x: 0, y: height)
            ))
        GroundTexture.grass(
            context, from: horizon + 6, height: height,
            color: world.greenery(Color(red: 0.48, green: 0.78, blue: 0.40)),
            world: world)
        Props.signpost(context, at: CGPoint(x: 88, y: horizon + 15))
        Props.log(context, at: CGPoint(x: 13, y: horizon + 31))
        Flora.tufts(
            context, rows: [horizon + 12, horizon + 24, horizon + 38],
            color: world.greenery(Color(red: 0.40, green: 0.68, blue: 0.34)), world: world)
        guard world.season != .winter else { return }
        Flora.flowers(
            context,
            at: [CGPoint(x: 10, y: horizon + 20), CGPoint(x: 88, y: horizon + 16), CGPoint(x: 82, y: horizon + 34)]
                + (world.season == .spring
                    ? [
                        CGPoint(x: 30, y: horizon + 30), CGPoint(x: 56, y: horizon + 14),
                        CGPoint(x: 64, y: horizon + 40),
                    ]
                    : []),
            world: world)
    }
}

enum Pond {
    static func draw(_ context: GraphicsContext, height: CGFloat, world: SceneWorld) {
        let horizon: CGFloat = 50
        Sky.draw(
            context, top: Color(red: 1, green: 0.78, blue: 0.70), bottom: Color(red: 1, green: 0.93, blue: 0.84),
            horizon: horizon, world: world)
        Distance.draw(
            context, horizon: horizon, style: .hills,
            tint: world.greenery(Color(red: 0.56, green: 0.80, blue: 0.52)).mix(
                with: Color(red: 1, green: 0.93, blue: 0.84), by: 0.5),
            world: world)
        let bank = Path(CGRect(x: 0, y: horizon, width: 100, height: height))
        context.fill(bank, with: .color(world.greenery(Color(red: 0.56, green: 0.80, blue: 0.52))))
        GroundTexture.grass(
            context, from: horizon + 30, height: height,
            color: world.greenery(Color(red: 0.5, green: 0.76, blue: 0.46)),
            path: false, world: world)
        let water = Path(ellipse: CGPoint(x: 50, y: horizon + 16), rx: 58, ry: 14)
        // In winter the pond freezes over: pale ice, no ripples.
        let frozen = world.season == .winter
        context.fill(
            water,
            with: .linearGradient(
                Gradient(
                    colors: [Color(red: 0.55, green: 0.85, blue: 0.95), Color(red: 0.36, green: 0.70, blue: 0.88)]
                        .map { frozen ? $0.mix(with: .white, by: 0.55) : $0 }),
                startPoint: CGPoint(x: 0, y: horizon + 2), endPoint: CGPoint(x: 0, y: horizon + 30)
            ))
        context.stroke(water, with: .color(Color(red: 0.42, green: 0.66, blue: 0.40)), lineWidth: 1.6)
        // Ripples spread out and fade, one after another.
        for (index, center) in [CGPoint(x: 30, y: horizon + 11), CGPoint(x: 68, y: horizon + 20)].enumerated()
        where !frozen {
            let spread = world.time == 0 ? 0.5 : world.cycle(3.6, offset: Double(index) * 0.5)
            let width = 5 + 10 * spread
            var ripple = Path()
            ripple.move(to: CGPoint(x: center.x - width / 2, y: center.y))
            ripple.addQuadCurve(
                to: CGPoint(x: center.x + width / 2, y: center.y), control: CGPoint(x: center.x, y: center.y - 1.5))
            context.stroke(
                ripple, with: .color(.white.opacity(0.8 * (1 - spread) + 0.1)),
                style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
        lilyPad(context, at: CGPoint(x: 16, y: horizon + 18 + 0.4 * world.wave(0.9)), size: 6)
        lilyPad(context, at: CGPoint(x: 84, y: horizon + 10 + 0.4 * world.wave(0.9, 2)), size: 5)
        Props.frog(context, at: CGPoint(x: 85, y: horizon + 10 + 0.4 * world.wave(0.9, 2)), world: world)
        Props.dock(context, at: horizon + 9)
        reeds(context, baseX: 92, baseY: horizon + 6, sway: world.sway(1.1))
        reeds(context, baseX: 6, baseY: horizon + 4, sway: world.sway(1.1, 1.3))
        Flora.tufts(
            context, rows: [horizon + 36, horizon + 46],
            color: world.greenery(Color(red: 0.42, green: 0.68, blue: 0.38)),
            world: world)
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

    /// Reeds leaning with the breeze, `sway` −1…1.
    static func reeds(_ context: GraphicsContext, baseX: CGFloat, baseY: CGFloat, sway: Double) {
        for (offset, tall) in [(-2.5, 16.0), (0, 22), (2.5, 14)] {
            let lean = CGFloat(sway) * tall * 0.07
            let tip = CGPoint(x: baseX + offset * 1.6 + lean, y: baseY - tall)
            var stem = Path()
            stem.move(to: CGPoint(x: baseX + offset, y: baseY))
            stem.addQuadCurve(to: tip, control: CGPoint(x: baseX + offset + lean * 0.3, y: baseY - tall / 2))
            context.stroke(
                stem, with: .color(Color(red: 0.36, green: 0.60, blue: 0.32)),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            if tall > 15 {
                let head = Path(
                    roundedRect: CGRect(x: tip.x - 1.3, y: tip.y, width: 2.6, height: 6), cornerRadius: 1.3)
                context.fill(head, with: .color(Color(red: 0.55, green: 0.36, blue: 0.24)))
            }
        }
    }
}

enum Flora {
    /// Rows of grass tufts whose tips sway in a breeze that rolls across the field.
    static func tufts(_ context: GraphicsContext, rows: [CGFloat], color: Color, world: SceneWorld) {
        for (row, baseY) in rows.enumerated() {
            for column in 0..<6 {
                let x = CGFloat(column) * 18 + (row.isMultiple(of: 2) ? 6 : 14)
                let sway = CGFloat(world.sway(1.4, Double(x) * 0.12 + Double(row))) * 0.7
                var tuft = Path()
                tuft.move(to: CGPoint(x: x - 2, y: baseY))
                tuft.addLine(to: CGPoint(x: x - 1 + sway, y: baseY - 2.5))
                tuft.move(to: CGPoint(x: x, y: baseY))
                tuft.addLine(to: CGPoint(x: x + 0.5 + sway, y: baseY - 3.5))
                tuft.move(to: CGPoint(x: x + 2, y: baseY))
                tuft.addLine(to: CGPoint(x: x + 2.5 + sway, y: baseY - 2.2))
                context.stroke(tuft, with: .color(color), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
            }
        }
    }

    static func flowers(_ context: GraphicsContext, at points: [CGPoint], world: SceneWorld) {
        let petals = [Color(red: 1, green: 0.75, blue: 0.85), Color.white, Color(red: 1, green: 0.85, blue: 0.4)]
        for (index, base) in points.enumerated() {
            // A little nod in the breeze.
            let center = CGPoint(x: base.x + CGFloat(world.sway(1.2, Double(index) * 2)) * 0.5, y: base.y)
            for petal in 0..<5 {
                let angle = Double(petal) / 5 * 2 * .pi
                let spot = CGPoint(x: center.x + cos(angle) * 1.6, y: center.y + sin(angle) * 1.6)
                context.fill(Path(ellipse: spot, rx: 1.3, ry: 1.3), with: .color(petals[index % petals.count]))
            }
            context.fill(Path(ellipse: center, rx: 0.9, ry: 0.9), with: .color(Color(red: 1, green: 0.8, blue: 0.3)))
        }
    }
}
