import FitchiCore
import SwiftUI

// Outdoor scenes. Same conventions as the meadow: a 100-wide art space, the horizon around
// y = 50–56 and ground that stretches to fill any extra height, so pets stand on it in every
// layout.

private func color(_ hex: UInt32) -> Color { PetColor(hex: hex).color }

private func fillGradient(_ context: GraphicsContext, _ rect: CGRect, _ top: UInt32, _ bottom: UInt32) {
    context.fill(
        Path(rect),
        with: .linearGradient(
            Gradient(colors: [color(top), color(bottom)]), startPoint: CGPoint(x: 0, y: rect.minY),
            endPoint: CGPoint(x: 0, y: rect.maxY)))
}

private func rollingHills(_ height: CGFloat, base: CGFloat, lift: CGFloat) -> Path {
    var hills = Path()
    hills.move(to: CGPoint(x: 0, y: base + 2))
    hills.addQuadCurve(to: CGPoint(x: 50, y: base), control: CGPoint(x: 22, y: base - lift))
    hills.addQuadCurve(to: CGPoint(x: 100, y: base + 1), control: CGPoint(x: 78, y: base - lift * 0.8))
    hills.addLine(to: CGPoint(x: 100, y: height))
    hills.addLine(to: CGPoint(x: 0, y: height))
    return hills
}

enum SnowyHill {
    static func draw(_ context: GraphicsContext, height: CGFloat, world: SceneWorld) {
        let horizon: CGFloat = 54
        Sky.draw(context, top: color(0xA9C8F0), bottom: color(0xE8EEFB), horizon: horizon, world: world)
        context.fill(rollingHills(height, base: horizon, lift: 14), with: .color(color(0xDCE7F7)))
        fillGradient(context, CGRect(x: 0, y: horizon + 6, width: 100, height: height), 0xFFFFFF, 0xE3ECF8)
        for (x, size) in [(10.0, 1.0), (88, 1.2), (77, 0.75)] {
            pine(context, at: CGPoint(x: x, y: horizon + 4 + (1 - size) * 6), size: size)
        }
        snowfall(context, height: height, world: world)
        for (x, y) in [(30.0, horizon + 22), (70, horizon + 30)] {
            context.fill(Path(ellipse: CGPoint(x: x, y: y), rx: 7, ry: 1.2), with: .color(color(0xC9D8EE)))
        }
    }

    /// Flakes drifting down the whole scene, each at its own pace, swaying as they fall.
    static func snowfall(_ context: GraphicsContext, height: CGFloat, world: SceneWorld, count: Int = 10) {
        // Across, how far down it starts (0…1) and how fast it falls.
        let flakes: [(x: Double, start: Double)] = [
            (14, 0.1), (36, 0.35), (58, 0.05), (70, 0.6), (92, 0.2), (46, 0.75), (24, 0.9), (84, 0.45), (6, 0.55),
            (64, 0.85),
        ]
        let fall = Double(height) + 6
        for (index, flake) in flakes.prefix(count).enumerated() {
            let speed = 3.8 + Double(index * 7 % 5) * 0.5
            let size = 0.8 + Double(index * 3 % 4) * 0.1
            let travelled = (flake.start * fall + world.time * speed).truncatingRemainder(dividingBy: fall)
            let center = CGPoint(x: flake.x + 2.5 * world.wave(0.8, Double(index)), y: travelled - 3)
            context.fill(Path(ellipse: center, rx: size, ry: size), with: .color(.white.opacity(0.9)))
        }
    }

    static func pine(_ context: GraphicsContext, at base: CGPoint, size: CGFloat) {
        context.fill(
            Path(CGRect(x: base.x - 1.2 * size, y: base.y - 4 * size, width: 2.4 * size, height: 4 * size)),
            with: .color(color(0x7A5638)))
        for tier in 0..<3 {
            let width = (10 - CGFloat(tier) * 2.6) * size
            let top = base.y - (10 + CGFloat(tier) * 6) * size
            var layer = Path()
            layer.move(to: CGPoint(x: base.x, y: top - 6 * size))
            layer.addLine(to: CGPoint(x: base.x + width / 2, y: top + 4 * size))
            layer.addLine(to: CGPoint(x: base.x - width / 2, y: top + 4 * size))
            layer.closeSubpath()
            context.fill(layer, with: .color(color(0x3E7D5A)))
            // Snow caps on each tier.
            context.fill(
                Path(ellipse: CGPoint(x: base.x, y: top - 3.5 * size), rx: 2 * size, ry: 1.2 * size),
                with: .color(.white))
        }
    }
}

enum Beach {
    static func draw(_ context: GraphicsContext, height: CGFloat, world: SceneWorld) {
        let horizon: CGFloat = 46
        Sky.draw(context, top: color(0x6EC6F5), bottom: color(0xD9F3FF), horizon: horizon, world: world)
        fillGradient(context, CGRect(x: 0, y: horizon, width: 100, height: 14), 0x4FB8DE, 0x7AD6EC)
        for (index, (startX, y)) in [(18.0, horizon + 4), (52, horizon + 7), (80, horizon + 3)].enumerated() {
            let x = startX + 3 * world.wave(0.6, Double(index) * 2)
            var wave = Path()
            wave.move(to: CGPoint(x: x - 5, y: y))
            wave.addQuadCurve(to: CGPoint(x: x + 5, y: y), control: CGPoint(x: x, y: y - 1.6))
            context.stroke(wave, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
        // Foam line, then sand. The tide laps in and out.
        let tide = 1.2 * world.wave(0.5)
        var shore = Path()
        shore.move(to: CGPoint(x: 0, y: horizon + 12 + tide))
        shore.addQuadCurve(
            to: CGPoint(x: 100, y: horizon + 11 + tide), control: CGPoint(x: 50, y: horizon + 15 + tide))
        shore.addLine(to: CGPoint(x: 100, y: height))
        shore.addLine(to: CGPoint(x: 0, y: height))
        context.fill(shore, with: .color(color(0xF7E3B5)))
        context.stroke(
            shore.trimmedPath(from: 0, to: 0.25), with: .color(.white),
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        palm(context, base: CGPoint(x: 8, y: horizon + 16), sway: world.sway(0.9))
        starfish(context, at: CGPoint(x: 86, y: horizon + 30))
        context.fill(Path(ellipse: CGPoint(x: 22, y: horizon + 34), rx: 2.4, ry: 1.6), with: .color(color(0xFFC7C2)))
    }

    static func palm(_ context: GraphicsContext, base: CGPoint, sway: Double) {
        var trunk = Path()
        trunk.move(to: base)
        trunk.addQuadCurve(to: CGPoint(x: base.x + 6, y: base.y - 34), control: CGPoint(x: base.x - 2, y: base.y - 18))
        context.stroke(trunk, with: .color(color(0xA5774D)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        let crown = CGPoint(x: base.x + 6, y: base.y - 34)
        for (index, start) in [-160.0, -120, -60, -20, 20].enumerated() {
            let angle = start + sway * 5 + sin(Double(index)) * sway * 2
            let tip = CGPoint(x: crown.x + cos(angle * .pi / 180) * 13, y: crown.y + sin(angle * .pi / 180) * 8 + 5)
            var frond = Path()
            frond.move(to: crown)
            frond.addQuadCurve(to: tip, control: CGPoint(x: (crown.x + tip.x) / 2, y: crown.y - 6))
            context.stroke(frond, with: .color(color(0x3FA35A)), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        }
    }

    static func starfish(_ context: GraphicsContext, at center: CGPoint) {
        var star = Path()
        for point in 0..<10 {
            let angle = Double(point) / 10 * 2 * .pi - .pi / 2
            let radius: CGFloat = point.isMultiple(of: 2) ? 3.6 : 1.5
            let spot = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius * 0.7)
            if point == 0 { star.move(to: spot) } else { star.addLine(to: spot) }
        }
        star.closeSubpath()
        context.fill(star, with: .color(color(0xFF9A6B)))
    }
}

enum StarryNight {
    static func draw(_ context: GraphicsContext, height: CGFloat, world: SceneWorld) {
        let horizon: CGFloat = 56
        fillGradient(context, CGRect(x: 0, y: 0, width: 100, height: horizon + 2), 0x1B2350, 0x4B4A86)
        // A crescent moon: a bright disc with a sky-coloured bite.
        context.fill(Path(ellipse: CGPoint(x: 78, y: 16), rx: 7, ry: 7), with: .color(color(0xFFF2B8)))
        context.fill(Path(ellipse: CGPoint(x: 81.5, y: 13.5), rx: 6, ry: 6), with: .color(color(0x232A5A)))
        Sky.drawStars(context, world: world, strength: 1)
        // Now and then a shooting star streaks across.
        let streak = world.cycle(23)
        if world.time > 0, streak < 0.05 {
            let progress = streak / 0.05
            let head = CGPoint(x: 20 + 40 * progress, y: 6 + 14 * progress)
            var trail = Path()
            trail.move(to: CGPoint(x: head.x - 9, y: head.y - 3.2))
            trail.addLine(to: head)
            context.stroke(
                trail,
                with: .linearGradient(
                    Gradient(colors: [.clear, .white.opacity(1 - progress * 0.6)]),
                    startPoint: CGPoint(x: head.x - 9, y: head.y - 3.2), endPoint: head),
                style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
        context.fill(rollingHills(height, base: horizon, lift: 12), with: .color(color(0x2E5A57)))
        fillGradient(context, CGRect(x: 0, y: horizon + 6, width: 100, height: height), 0x3C7A6A, 0x2B5C55)
        Flora.tufts(context, rows: [horizon + 14, horizon + 28], color: color(0x24504A), world: world)
        Fireflies.draw(context, world: world, around: horizon + 4, strength: 1)
    }
}

enum Forest {
    static func draw(_ context: GraphicsContext, height: CGFloat, world: SceneWorld) {
        let horizon: CGFloat = 56
        Sky.draw(context, top: color(0xA8DCC4), bottom: color(0xE4F5E8), horizon: horizon, world: world)
        // Two rows of round treetops: a hazy one behind, a darker one in front.
        for (index, x) in stride(from: -4.0, through: 104, by: 14).enumerated() {
            tree(
                context, at: CGPoint(x: x, y: horizon - 6), radius: 10,
                crown: world.season == .autumn
                    ? Season.autumnLeaves[index % 3].mix(with: .white, by: 0.25) : world.greenery(color(0x86C49A)),
                trunk: 0x9C7A5C, lift: index % 2 == 0 ? 0 : 4)
        }
        for (index, x) in [4.0, 22, 80, 97].enumerated() {
            tree(
                context, at: CGPoint(x: x, y: horizon + 2), radius: 12,
                crown: world.season == .autumn ? Season.autumnLeaves[(index + 1) % 3] : world.greenery(color(0x4E9A68)),
                trunk: 0x7A5638, lift: index % 2 == 0 ? 2 : 6, blossom: world.season == .spring)
        }
        context.fill(
            Path(CGRect(x: 0, y: horizon, width: 100, height: height)),
            with: .linearGradient(
                Gradient(colors: [world.greenery(color(0x7BC173)), world.greenery(color(0x5EA45C))]),
                startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: height)))
        Flora.tufts(
            context, rows: [horizon + 10, horizon + 24, horizon + 38], color: world.greenery(color(0x4C8C4A)),
            world: world)
        mushroom(context, at: CGPoint(x: 14, y: horizon + 22))
        mushroom(context, at: CGPoint(x: 88, y: horizon + 30))
        if world.time > 0, world.season != .winter { fallingLeaves(context, horizon: horizon, world: world) }
    }

    /// A couple of leaves let go of the front trees and flutter down to the grass.
    static func fallingLeaves(_ context: GraphicsContext, horizon: CGFloat, world: SceneWorld) {
        for (index, (startX, period)) in [(22.0, 11.0), (80, 14)].enumerated() {
            let progress = world.cycle(period, offset: Double(index) * 0.4)
            // Falls for the first 60% of its cycle, rests on the grass a moment, then is gone.
            guard progress < 0.75 else { continue }
            let fall = min(1, progress / 0.6)
            let center = CGPoint(
                x: startX + 6 * sin(fall * .pi * 3) + 8 * fall, y: horizon - 22 + fall * 34)
            let angle = 40 * sin(fall * .pi * 3)
            let fade = progress > 0.6 ? 1 - (progress - 0.6) / 0.15 : 1
            context.fill(
                Path(ellipse: center, rx: 1.8, ry: 0.9, degrees: angle),
                with: .color(color(index == 0 ? 0xE8A33D : 0xC9663B).opacity(fade)))
        }
    }

    static func tree(
        _ context: GraphicsContext, at base: CGPoint, radius: CGFloat, crown: Color, trunk: UInt32, lift: CGFloat,
        blossom: Bool = false
    ) {
        context.fill(
            Path(CGRect(x: base.x - 1.8, y: base.y - radius - lift, width: 3.6, height: radius + lift)),
            with: .color(color(trunk)))
        var leaves = Path()
        for (offsetX, offsetY, scale) in [(-0.45, 0.1, 0.7), (0.45, 0.1, 0.7), (0, -0.35, 0.85)] {
            leaves.addEllipse(
                in: CGRect(
                    x: base.x + offsetX * radius - radius * scale,
                    y: base.y - radius * 1.6 - lift + offsetY * radius - radius * scale,
                    width: radius * 2 * scale, height: radius * 2 * scale))
        }
        context.fill(leaves, with: .color(crown))
        if blossom {
            // Spring blossom dotted over the crown.
            for (offsetX, offsetY) in [(-0.6, -1.5), (0.1, -2.1), (0.6, -1.3), (-0.2, -1.1), (0.35, -1.8)] {
                context.fill(
                    Path(
                        ellipse: CGPoint(x: base.x + offsetX * radius, y: base.y + offsetY * radius - lift), rx: 1.3,
                        ry: 1.3),
                    with: .color(Color(red: 1, green: 0.8, blue: 0.88)))
            }
        }
    }

    static func mushroom(_ context: GraphicsContext, at base: CGPoint) {
        context.fill(
            Path(roundedRect: CGRect(x: base.x - 1.5, y: base.y - 4, width: 3, height: 4.5), cornerRadius: 1),
            with: .color(color(0xFFF4E0)))
        var cap = Path()
        cap.addArc(
            center: CGPoint(x: base.x, y: base.y - 3.5), radius: 4.5, startAngle: .degrees(180), endAngle: .zero,
            clockwise: false)
        cap.closeSubpath()
        context.fill(cap, with: .color(color(0xE8524A)))
        for (offsetX, offsetY) in [(-2.0, -5.5), (1.6, -6.2), (0.2, -4.3)] {
            context.fill(
                Path(ellipse: CGPoint(x: base.x + offsetX, y: base.y + offsetY), rx: 0.8, ry: 0.7), with: .color(.white)
            )
        }
    }
}

/// A cottage garden: a hedge and a white picket fence along the horizon, tulip beds to either
/// side and stepping stones across the lawn. Changes with the seasons like the meadow.
enum Garden {
    static func draw(_ context: GraphicsContext, height: CGFloat, world: SceneWorld) {
        let horizon: CGFloat = 56
        Sky.draw(context, top: color(0x8FD3FF), bottom: color(0xE2F4FF), horizon: horizon, world: world)
        // A row of round bushes behind the fence, each with a soft highlight.
        var hedge = Path(CGRect(x: 0, y: horizon - 7, width: 100, height: 7))
        for x in stride(from: 0.0, through: 100, by: 10) {
            hedge.addEllipse(in: CGRect(x: x - 7.5, y: horizon - 15, width: 15, height: 15))
        }
        context.fill(hedge, with: .color(world.greenery(color(0x5FA866))))
        for x in stride(from: 0.0, through: 100, by: 10) {
            context.fill(
                Path(ellipse: CGPoint(x: x - 2, y: horizon - 11), rx: 3, ry: 1.8),
                with: .color(world.greenery(color(0x7CC27F)).opacity(0.8)))
        }
        fillGradient(context, CGRect(x: 0, y: horizon, width: 100, height: height - horizon), 0x8FD27A, 0x6CBB5E)
        fence(context, base: horizon + 1)
        Flora.tufts(
            context, rows: [horizon + 14, horizon + 30], color: world.greenery(color(0x4F9A4A)), world: world)
        // Stepping stones winding towards the front.
        for (index, (x, y)) in [(52.0, 8.0), (46, 16), (53, 25), (45, 35)].enumerated() {
            let size = 3.2 + CGFloat(index) * 0.7
            context.fill(
                Path(ellipse: CGPoint(x: x, y: horizon + y), rx: size, ry: size * 0.45),
                with: .color(color(0xD9D2C3)))
        }
        bed(context, center: CGPoint(x: 13, y: horizon + 12), world: world, seed: 0)
        bed(context, center: CGPoint(x: 88, y: horizon + 18), world: world, seed: 3)
        wateringCan(context, at: CGPoint(x: 24, y: horizon + 22))
    }

    private static func fence(_ context: GraphicsContext, base: CGFloat) {
        for y in [base - 6, base - 2.5] {
            context.fill(Path(CGRect(x: 0, y: y, width: 100, height: 1.3)), with: .color(color(0xF4F1EA)))
        }
        for x in stride(from: 2.0, through: 98, by: 5) {
            let picket = Path(
                roundedPolygon: [
                    CGPoint(x: x - 1.3, y: base), CGPoint(x: x - 1.3, y: base - 8), CGPoint(x: x, y: base - 9.6),
                    CGPoint(x: x + 1.3, y: base - 8), CGPoint(x: x + 1.3, y: base),
                ], radius: 0.4)
            context.fill(picket, with: .color(.white))
            context.stroke(picket, with: .color(color(0xC9C2B4)), lineWidth: 0.35)
        }
    }

    /// A bed of soil with tulips nodding in the breeze (bare in winter, fuller in spring).
    private static func bed(_ context: GraphicsContext, center: CGPoint, world: SceneWorld, seed: Int) {
        context.fill(Path(ellipse: center, rx: 12, ry: 4), with: .color(color(0x8B6646)))
        guard world.season != .winter else { return }
        let colours: [UInt32] =
            world.season == .autumn ? [0xF08A3C, 0xD9573B, 0xF2B640] : [0xFF5C7A, 0xFFD54D, 0xFF9EC0]
        let count = world.season == .spring ? 6 : 4
        for index in 0..<count {
            let x = center.x - 9 + CGFloat(index) * (18 / CGFloat(count - 1))
            let sway = CGFloat(world.sway(1.3, Double(index + seed) * 1.7)) * 0.8
            let top = CGPoint(x: x + sway, y: center.y - 7 - CGFloat((index + seed) % 2) * 1.5)
            var stem = Path()
            stem.move(to: CGPoint(x: x, y: center.y))
            stem.addQuadCurve(to: top, control: CGPoint(x: x, y: center.y - 4))
            context.stroke(stem, with: .color(color(0x3E8A45)), lineWidth: 0.8)
            context.fill(
                Path(ellipse: CGPoint(x: x - 1.2, y: center.y - 2.5), rx: 1.6, ry: 0.7, degrees: -40),
                with: .color(color(0x4FA052)))
            var cup = Path()
            cup.move(to: CGPoint(x: top.x - 1.7, y: top.y - 2))
            cup.addLine(to: CGPoint(x: top.x - 0.6, y: top.y - 1))
            cup.addLine(to: CGPoint(x: top.x, y: top.y - 2.4))
            cup.addLine(to: CGPoint(x: top.x + 0.6, y: top.y - 1))
            cup.addLine(to: CGPoint(x: top.x + 1.7, y: top.y - 2))
            cup.addQuadCurve(to: CGPoint(x: top.x - 1.7, y: top.y - 2), control: CGPoint(x: top.x, y: top.y + 2.4))
            context.fill(cup, with: .color(color(colours[(index + seed) % colours.count])))
        }
    }

    private static func wateringCan(_ context: GraphicsContext, at base: CGPoint) {
        let body = Path(roundedRect: CGRect(x: base.x - 3, y: base.y - 5, width: 6, height: 5), cornerRadius: 1.2)
        var spout = Path()
        spout.move(to: CGPoint(x: base.x + 2.5, y: base.y - 1.5))
        spout.addLine(to: CGPoint(x: base.x + 6.5, y: base.y - 5.5))
        context.stroke(spout, with: .color(color(0x4FA3E0)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        var handle = Path()
        handle.addArc(
            center: CGPoint(x: base.x, y: base.y - 5), radius: 2.4, startAngle: .degrees(180), endAngle: .degrees(0),
            clockwise: false)
        context.stroke(handle, with: .color(color(0x3A86C2)), lineWidth: 0.9)
        context.fill(body, with: .color(color(0x4FA3E0)))
        context.fill(
            Path(ellipse: CGPoint(x: base.x, y: base.y + 0.2), rx: 4.5, ry: 0.9), with: .color(.black.opacity(0.12)))
    }
}
