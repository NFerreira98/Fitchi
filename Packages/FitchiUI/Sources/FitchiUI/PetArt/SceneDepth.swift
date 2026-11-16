import SwiftUI

// Depth for the scenes: faraway land in haze behind the horizon, texture on the ground, light in
// the air and a soft vignette. Shared by every backdrop, so they all get it at once.

private func color(_ hex: UInt32) -> Color { PetColor(hex: hex).color }

/// Land far beyond the horizon, in the hazy colour of the sky. It drifts very slowly against the
/// clouds: the parallax of something a long way off.
enum Distance {
    enum Style {
        /// Soft rolling hills.
        case hills
        /// A row of round treetops.
        case treeline
        /// Jagged mountains.
        case peaks
        /// Dark hills against a night sky.
        case silhouette
        /// A low island or two across the water.
        case islands
    }

    static func draw(_ context: GraphicsContext, horizon: CGFloat, style: Style, tint: Color, world: SceneWorld) {
        let haze: Color = style == .silhouette ? .black : .white
        // Two rows: the farther one paler and higher, the nearer one a touch deeper and lower.
        let rows = [
            Row(lift: 15, drop: 1.5, phase: 0.8, speed: 0.045, mix: 0.5),
            Row(lift: 9, drop: 0.5, phase: 2.9, speed: 0.09, mix: 0.25),
        ]
        for row in rows {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: horizon + 3))
            let shift = world.time * row.speed
            for step in 0...50 {
                let x = CGFloat(step) * 2
                let rise = row.lift * bump(Double(x) + shift, phase: row.phase, style: style)
                path.addLine(to: CGPoint(x: x, y: horizon + row.drop - rise))
            }
            path.addLine(to: CGPoint(x: 100, y: horizon + 3))
            path.closeSubpath()
            context.fill(path, with: .color(tint.mix(with: haze, by: row.mix)))
        }
    }

    private struct Row {
        var lift: CGFloat
        var drop: CGFloat
        var phase: Double
        var speed: Double
        /// How far it fades into the haze.
        var mix: Double
    }

    /// How tall the far land is at `x`, 0…1, in the shape of each style.
    static func bump(_ x: Double, phase: Double, style: Style) -> Double {
        let wave = 0.5 + 0.5 * sin(x / 60 * 2 * .pi + phase)
        let detail = 0.5 + 0.5 * sin(x / 23 * 2 * .pi + phase * 1.7)
        switch style {
        case .hills, .silhouette:
            return wave * 0.75 + detail * 0.25
        case .treeline:
            return 0.5 + 0.5 * abs(sin(x / 9 * .pi + phase))
        case .peaks:
            let along = (x / 30 + phase).truncatingRemainder(dividingBy: 1)
            return (1 - abs(2 * along - 1)) * 0.75 + detail * 0.25
        case .islands:
            return max(0, wave - 0.62) * 2
        }
    }
}

/// What the ground is made of up close: not one flat colour.
enum GroundTexture {
    /// Grass: darker patches where it grows thick, clover, a few pebbles and (unless told not
    /// to) a worn path wandering in from the back.
    static func grass(
        _ context: GraphicsContext, from top: CGFloat, height: CGFloat, color base: Color, path: Bool = true,
        world: SceneWorld
    ) {
        let dark = base.mix(with: .black, by: 0.5)
        let depth = max(1, height - top)
        if path {
            let worn = base.mix(with: Color(red: 0.95, green: 0.88, blue: 0.62), by: 0.6)
            var trail = Path()
            trail.move(to: CGPoint(x: 56, y: top + 1))
            trail.addCurve(
                to: CGPoint(x: 32, y: height + 2), control1: CGPoint(x: 66, y: top + depth * 0.4),
                control2: CGPoint(x: 24, y: top + depth * 0.7))
            trail.addLine(to: CGPoint(x: 54, y: height + 2))
            trail.addCurve(
                to: CGPoint(x: 61, y: top + 1), control1: CGPoint(x: 42, y: top + depth * 0.7),
                control2: CGPoint(x: 72, y: top + depth * 0.4))
            trail.closeSubpath()
            context.fill(trail, with: .color(worn.opacity(0.32)))
        }
        for (x, along, width) in [(14.0, 0.25, 16.0), (84, 0.45, 20), (40, 0.62, 14), (70, 0.85, 22), (10, 0.9, 18)] {
            context.fill(
                Path(ellipse: CGPoint(x: x, y: top + depth * along), rx: width / 2, ry: width * 0.12),
                with: .color(dark.opacity(0.1)))
        }
        for (x, along) in [(22.0, 0.3), (78, 0.2), (62, 0.5), (18, 0.7), (90, 0.75), (48, 0.95)] {
            let spot = CGPoint(x: x, y: top + depth * along)
            for (shiftX, shiftY) in [(-0.9, 0.0), (0.9, 0), (0, -0.8)] {
                context.fill(
                    Path(ellipse: CGPoint(x: spot.x + shiftX, y: spot.y + shiftY), rx: 0.9, ry: 0.7),
                    with: .color(dark.opacity(0.3)))
            }
        }
        pebbles(
            context,
            at: [
                (CGPoint(x: 30, y: top + depth * 0.42), 1.6), (CGPoint(x: 72, y: top + depth * 0.68), 1.2),
                (CGPoint(x: 8, y: top + depth * 0.55), 1.1),
            ])
    }

    /// Snow: long soft drifts and a sparkle on the crust.
    static func snow(_ context: GraphicsContext, from top: CGFloat, height: CGFloat, world: SceneWorld) {
        let depth = max(1, height - top)
        for (x, along, width) in [(20.0, 0.3, 30.0), (74, 0.5, 36), (40, 0.8, 40)] {
            let center = CGPoint(x: x, y: top + depth * along)
            context.fill(
                Path(ellipse: center, rx: width / 2, ry: width * 0.07), with: .color(color(0xD4E0F2).opacity(0.5)))
            context.fill(
                Path(ellipse: CGPoint(x: center.x - 2, y: center.y - 1), rx: width / 2.6, ry: width * 0.04),
                with: .color(.white.opacity(0.7)))
        }
        for (index, (x, along)) in [(12.0, 0.2), (58, 0.35), (88, 0.6), (34, 0.7), (66, 0.92), (6, 0.85)].enumerated() {
            let twinkle = 0.3 + 0.7 * max(0, world.wave(1.7, Double(index) * 1.3))
            context.fill(
                Sparkles.star(at: CGPoint(x: x, y: top + depth * along), size: 1.4),
                with: .color(.white.opacity(twinkle)))
        }
    }

    /// Sand: ripples left by the tide, and a couple of shells.
    static func sand(_ context: GraphicsContext, from top: CGFloat, height: CGFloat, world: SceneWorld) {
        let depth = max(1, height - top)
        for (index, along) in [0.25, 0.45, 0.65, 0.85].enumerated() {
            let y = top + depth * along
            var ripple = Path()
            ripple.move(to: CGPoint(x: -2, y: y))
            for step in 1...12 {
                let x = CGFloat(step) * 9 - 2
                ripple.addQuadCurve(
                    to: CGPoint(x: x, y: y), control: CGPoint(x: x - 4.5, y: y + (step.isMultiple(of: 2) ? 1.2 : -1.2)))
            }
            context.stroke(
                ripple, with: .color(color(0xD9BF86).opacity(0.3 - Double(index) * 0.04)),
                style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        }
        for (x, along, flip) in [(70.0, 0.55, 1.0), (28, 0.9, -1.0)] {
            let base = CGPoint(x: x, y: top + depth * along)
            var shell = Path()
            shell.move(to: base)
            shell.addArc(
                center: base, radius: 2.6, startAngle: .degrees(flip > 0 ? 200 : 160),
                endAngle: .degrees(flip > 0 ? 340 : 20), clockwise: flip < 0)
            shell.closeSubpath()
            context.fill(shell, with: .color(color(0xFFD9D2)))
            context.stroke(shell, with: .color(color(0xE8A89C)), lineWidth: 0.5)
        }
    }

    private static func pebbles(_ context: GraphicsContext, at spots: [(CGPoint, CGFloat)]) {
        for (spot, radius) in spots {
            let (x, y) = (spot.x, spot.y)
            context.fill(
                Path(ellipse: CGPoint(x: x, y: y), rx: radius, ry: radius * 0.7),
                with: .color(Color(red: 0.62, green: 0.6, blue: 0.56)))
            context.fill(
                Path(ellipse: CGPoint(x: x - radius * 0.3, y: y - radius * 0.3), rx: radius * 0.4, ry: radius * 0.25),
                with: .color(.white.opacity(0.5)))
        }
    }
}

/// Light in the air between you and the scene.
enum Air {
    /// Faint shafts of sunlight fanning down from the sun, swaying slowly; gone at night and in
    /// dull weather.
    static func rays(_ context: GraphicsContext, horizon: CGFloat, height: CGFloat, world: SceneWorld) {
        guard let progress = world.light.sun else { return }
        let strength = max(0, 1 - world.light.night * 2) * (1 - world.weather.overcast) * 0.11
        guard strength > 0.01 else { return }
        let sun = Sky.sunCenter(horizon: horizon, progress: progress)
        for ray in 0..<3 {
            let angle = Double.pi / 2 + (Double(ray) - 1) * 0.42 + 0.06 * world.wave(0.17, Double(ray))
            let width = 0.14 + Double(ray % 2) * 0.05
            let far: CGFloat = 170
            var wedge = Path()
            wedge.move(to: sun)
            wedge.addLine(to: CGPoint(x: sun.x + cos(angle - width) * far, y: sun.y + sin(angle - width) * far))
            wedge.addLine(to: CGPoint(x: sun.x + cos(angle + width) * far, y: sun.y + sin(angle + width) * far))
            wedge.closeSubpath()
            context.fill(
                wedge,
                with: .linearGradient(
                    Gradient(colors: [Color(red: 1, green: 0.97, blue: 0.8).opacity(strength), .clear]),
                    startPoint: sun, endPoint: CGPoint(x: sun.x, y: sun.y + height * 0.9)))
        }
    }

    /// Pollen and dust glinting as it drifts up through the light, by day.
    static func motes(_ context: GraphicsContext, height: CGFloat, world: SceneWorld) {
        let strength = (1 - world.light.night) * (1 - 0.7 * world.weather.overcast) * 0.5
        guard strength > 0.02, world.time > 0 else { return }
        for index in 0..<9 {
            let seed = Double(index)
            let cycle = world.cycle(14 + seed * 1.3, offset: seed * 0.37)
            let x = (seed * 11.3 + 7 + cycle * 18 + 4 * world.wave(0.5, seed)).truncatingRemainder(dividingBy: 100)
            let y = height * (1 - cycle) * 0.95
            let twinkle = 0.5 + 0.5 * world.wave(2.3, seed * 1.9)
            context.fill(
                Path(ellipse: CGPoint(x: x, y: y), rx: 0.7, ry: 0.7),
                with: .color(Color(red: 1, green: 0.98, blue: 0.85).opacity(strength * twinkle)))
        }
    }

    /// A soft darkening towards the corners that draws the eye to the middle.
    static func vignette(_ context: GraphicsContext, height: CGFloat, indoor: Bool) {
        context.fill(
            Path(CGRect(x: 0, y: 0, width: 100, height: height)),
            with: .radialGradient(
                Gradient(colors: [.clear, .clear, .black.opacity(indoor ? 0.12 : 0.15)]),
                center: CGPoint(x: 50, y: height * 0.45), startRadius: 0, endRadius: max(70, height * 0.85)))
    }
}
