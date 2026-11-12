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
    static func draw(_ context: GraphicsContext, height: CGFloat) {
        let horizon: CGFloat = 54
        Sky.draw(context, top: color(0xA9C8F0), bottom: color(0xE8EEFB), horizon: horizon)
        context.fill(rollingHills(height, base: horizon, lift: 14), with: .color(color(0xDCE7F7)))
        fillGradient(context, CGRect(x: 0, y: horizon + 6, width: 100, height: height), 0xFFFFFF, 0xE3ECF8)
        for (x, size) in [(10.0, 1.0), (88, 1.2), (77, 0.75)] {
            pine(context, at: CGPoint(x: x, y: horizon + 4 + (1 - size) * 6), size: size)
        }
        // Gentle snowfall.
        for (x, y) in [(14.0, 10.0), (36, 22), (58, 8), (70, 34), (92, 14), (46, 40), (24, 44), (84, 46)] {
            context.fill(Path(ellipse: CGPoint(x: x, y: y), rx: 1, ry: 1), with: .color(.white.opacity(0.9)))
        }
        for (x, y) in [(30.0, horizon + 22), (70, horizon + 30)] {
            context.fill(Path(ellipse: CGPoint(x: x, y: y), rx: 7, ry: 1.2), with: .color(color(0xC9D8EE)))
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
    static func draw(_ context: GraphicsContext, height: CGFloat) {
        let horizon: CGFloat = 46
        Sky.draw(context, top: color(0x6EC6F5), bottom: color(0xD9F3FF), horizon: horizon)
        context.fill(Path(ellipse: CGPoint(x: 82, y: 14), rx: 7, ry: 7), with: .color(color(0xFFE27A)))
        fillGradient(context, CGRect(x: 0, y: horizon, width: 100, height: 12), 0x4FB8DE, 0x7AD6EC)
        for (x, y) in [(18.0, horizon + 4), (52, horizon + 7), (80, horizon + 3)] {
            var wave = Path()
            wave.move(to: CGPoint(x: x - 5, y: y))
            wave.addQuadCurve(to: CGPoint(x: x + 5, y: y), control: CGPoint(x: x, y: y - 1.6))
            context.stroke(wave, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
        // Foam line, then sand.
        var shore = Path()
        shore.move(to: CGPoint(x: 0, y: horizon + 12))
        shore.addQuadCurve(to: CGPoint(x: 100, y: horizon + 11), control: CGPoint(x: 50, y: horizon + 15))
        shore.addLine(to: CGPoint(x: 100, y: height))
        shore.addLine(to: CGPoint(x: 0, y: height))
        context.fill(shore, with: .color(color(0xF7E3B5)))
        context.stroke(
            shore.trimmedPath(from: 0, to: 0.25), with: .color(.white),
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        palm(context, base: CGPoint(x: 8, y: horizon + 16))
        starfish(context, at: CGPoint(x: 86, y: horizon + 30))
        context.fill(Path(ellipse: CGPoint(x: 22, y: horizon + 34), rx: 2.4, ry: 1.6), with: .color(color(0xFFC7C2)))
    }

    static func palm(_ context: GraphicsContext, base: CGPoint) {
        var trunk = Path()
        trunk.move(to: base)
        trunk.addQuadCurve(to: CGPoint(x: base.x + 6, y: base.y - 34), control: CGPoint(x: base.x - 2, y: base.y - 18))
        context.stroke(trunk, with: .color(color(0xA5774D)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        let crown = CGPoint(x: base.x + 6, y: base.y - 34)
        for angle in [-160.0, -120, -60, -20, 20] {
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
    static func draw(_ context: GraphicsContext, height: CGFloat) {
        let horizon: CGFloat = 56
        fillGradient(context, CGRect(x: 0, y: 0, width: 100, height: horizon + 2), 0x1B2350, 0x4B4A86)
        // A crescent moon: a bright disc with a sky-coloured bite.
        context.fill(Path(ellipse: CGPoint(x: 78, y: 16), rx: 7, ry: 7), with: .color(color(0xFFF2B8)))
        context.fill(Path(ellipse: CGPoint(x: 81.5, y: 13.5), rx: 6, ry: 6), with: .color(color(0x232A5A)))
        for (x, y, size) in [
            (12.0, 10.0, 1.6), (30, 22, 1.1), (46, 8, 1.8), (60, 28, 1.0), (22, 36, 1.2), (92, 34, 1.3),
        ] {
            context.fill(Sparkles.star(at: CGPoint(x: x, y: y), size: size), with: .color(color(0xFFF6D6)))
        }
        context.fill(rollingHills(height, base: horizon, lift: 12), with: .color(color(0x2E5A57)))
        fillGradient(context, CGRect(x: 0, y: horizon + 6, width: 100, height: height), 0x3C7A6A, 0x2B5C55)
        Flora.tufts(context, rows: [horizon + 14, horizon + 28], color: color(0x24504A))
        // Fireflies.
        for (x, y) in [(16.0, horizon + 4), (84, horizon - 2), (66, horizon + 18)] {
            context.fill(
                Path(ellipse: CGPoint(x: x, y: y), rx: 2.6, ry: 2.6), with: .color(color(0xFFF07A).opacity(0.25)))
            context.fill(Path(ellipse: CGPoint(x: x, y: y), rx: 1, ry: 1), with: .color(color(0xFFF07A)))
        }
    }
}

enum Forest {
    static func draw(_ context: GraphicsContext, height: CGFloat) {
        let horizon: CGFloat = 56
        Sky.draw(context, top: color(0xA8DCC4), bottom: color(0xE4F5E8), horizon: horizon)
        // Two rows of round treetops: a hazy one behind, a darker one in front.
        for (index, x) in stride(from: -4.0, through: 104, by: 14).enumerated() {
            tree(
                context, at: CGPoint(x: x, y: horizon - 6), radius: 10, crown: 0x86C49A, trunk: 0x9C7A5C,
                lift: index % 2 == 0 ? 0 : 4)
        }
        for (index, x) in [4.0, 22, 80, 97].enumerated() {
            tree(
                context, at: CGPoint(x: x, y: horizon + 2), radius: 12, crown: 0x4E9A68, trunk: 0x7A5638,
                lift: index % 2 == 0 ? 2 : 6)
        }
        fillGradient(context, CGRect(x: 0, y: horizon, width: 100, height: height), 0x7BC173, 0x5EA45C)
        Flora.tufts(context, rows: [horizon + 10, horizon + 24, horizon + 38], color: color(0x4C8C4A))
        mushroom(context, at: CGPoint(x: 14, y: horizon + 22))
        mushroom(context, at: CGPoint(x: 88, y: horizon + 30))
    }

    static func tree(
        _ context: GraphicsContext, at base: CGPoint, radius: CGFloat, crown: UInt32, trunk: UInt32, lift: CGFloat
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
        context.fill(leaves, with: .color(color(crown)))
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
