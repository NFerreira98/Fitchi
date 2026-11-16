import SwiftUI

// Home scenes: a wall down to the floor line (y = 56, where outdoor horizons sit), a floor that
// stretches to fill any extra height, and furniture kept to the sides so the pet stays the star.

private func color(_ hex: UInt32) -> Color { PetColor(hex: hex).color }

private let floorLine: CGFloat = 56

/// Wall, skirting board and a wooden plank floor.
private func room(_ context: GraphicsContext, height: CGFloat, wall: UInt32, floor: UInt32, planks: UInt32) {
    context.fill(Path(CGRect(x: 0, y: 0, width: 100, height: floorLine)), with: .color(color(wall)))
    context.fill(Path(CGRect(x: 0, y: floorLine, width: 100, height: height)), with: .color(color(floor)))
    for row in 1..<8 {
        let y = floorLine + CGFloat(row) * 7
        var seam = Path()
        seam.move(to: CGPoint(x: 0, y: y))
        seam.addLine(to: CGPoint(x: 100, y: y))
        context.stroke(seam, with: .color(color(planks).opacity(0.5)), lineWidth: 0.6)
    }
    context.fill(Path(CGRect(x: 0, y: floorLine - 2.5, width: 100, height: 2.5)), with: .color(.white.opacity(0.75)))
}

private func rug(_ context: GraphicsContext, fill: UInt32, trim: UInt32) {
    let rug = Path(ellipse: CGPoint(x: 50, y: floorLine + 22), rx: 34, ry: 9)
    context.fill(rug, with: .color(color(fill)))
    context.stroke(
        rug.applying(.identity), with: .color(color(trim)), style: StrokeStyle(lineWidth: 1.4, dash: [2, 2]))
}

/// A window with sky, a cloud and curtains. At night it shows a dark sky and the moon.
private func window(_ context: GraphicsContext, frame rect: CGRect, curtain: UInt32, world: SceneWorld) {
    context.fill(Path(roundedRect: rect.insetBy(dx: -1.5, dy: -1.5), cornerRadius: 2), with: .color(.white))
    context.fill(
        Path(rect),
        with: .linearGradient(
            Gradient(colors: [color(0x8FD0FF), color(0xD8F0FF)]), startPoint: CGPoint(x: 0, y: rect.minY),
            endPoint: CGPoint(x: 0, y: rect.maxY)))
    var glass = context
    glass.clip(to: Path(rect))
    let drift = CGFloat(world.cycle(60)) * (rect.width + 10) - 5
    Sky.cloud(glass, at: CGPoint(x: rect.minX + drift, y: rect.midY), size: 0.45)
    WeatherArt.window(glass, rect: rect, world: world)
    let night = world.light.night
    if night > 0.01 {
        glass.fill(Path(rect), with: .color(color(0x1B2350).opacity(0.9 * night)))
        glass.fill(
            Path(ellipse: CGPoint(x: rect.minX + rect.width * 0.7, y: rect.minY + rect.height * 0.3), rx: 2.2, ry: 2.2),
            with: .color(color(0xFFF4C8).opacity(night)))
    }
    context.fill(Path(CGRect(x: rect.midX - 0.6, y: rect.minY, width: 1.2, height: rect.height)), with: .color(.white))
    for side in [rect.minX - 3, rect.maxX - 2] {
        context.fill(
            Path(roundedRect: CGRect(x: side, y: rect.minY - 3, width: 5, height: rect.height + 6), cornerRadius: 2),
            with: .color(color(curtain)))
    }
}

enum Bedroom {
    static func draw(_ context: GraphicsContext, height: CGFloat, world: SceneWorld) {
        room(context, height: height, wall: 0xE6DCF7, floor: 0xE8C9A0, planks: 0xC9A27A)
        // Little star wallpaper.
        for (index, (x, y)) in [(10.0, 8.0), (30, 18), (52, 6), (70, 20), (90, 9), (40, 34), (62, 40)].enumerated() {
            let twinkle = 0.6 + 0.2 * world.wave(0.9, Double(index) * 1.7)
            context.fill(Sparkles.star(at: CGPoint(x: x, y: y), size: 1.6), with: .color(.white.opacity(twinkle)))
        }
        window(context, frame: CGRect(x: 8, y: 12, width: 18, height: 20), curtain: 0xB79CE8, world: world)
        bed(context)
        // A bedside lamp glowing on the left.
        context.fill(Path(CGRect(x: 6, y: floorLine - 12, width: 10, height: 12)), with: .color(color(0xC59A72)))
        context.fill(Path(CGRect(x: 10.2, y: floorLine - 20, width: 1.6, height: 8)), with: .color(color(0x8C6B4F)))
        var shade = Path()
        shade.move(to: CGPoint(x: 7, y: floorLine - 20))
        shade.addLine(to: CGPoint(x: 15, y: floorLine - 20))
        shade.addLine(to: CGPoint(x: 13, y: floorLine - 26))
        shade.addLine(to: CGPoint(x: 9, y: floorLine - 26))
        shade.closeSubpath()
        context.fill(
            Path(ellipse: CGPoint(x: 11, y: floorLine - 22), rx: 9, ry: 7), with: .color(color(0xFFF1B8).opacity(0.35)))
        context.fill(shade, with: .color(color(0xFFE28A)))
        rug(context, fill: 0xF4B8C8, trim: 0xFFFFFF)
    }

    /// The bedside lamp's bulb, for its glow at night.
    static let lamp = CGPoint(x: 11, y: floorLine - 22)

    /// A bed against the right wall, partly out of frame.
    private static func bed(_ context: GraphicsContext) {
        context.fill(
            Path(roundedRect: CGRect(x: 78, y: floorLine - 30, width: 30, height: 30), cornerRadius: 4),
            with: .color(color(0x9C7A5C)))
        context.fill(
            Path(roundedRect: CGRect(x: 72, y: floorLine - 14, width: 34, height: 12), cornerRadius: 3),
            with: .color(color(0xFFFFFF)))
        context.fill(
            Path(roundedRect: CGRect(x: 80, y: floorLine - 20, width: 18, height: 7), cornerRadius: 3.5),
            with: .color(color(0xF7F3FF)))
        context.fill(
            Path(roundedRect: CGRect(x: 70, y: floorLine - 12, width: 36, height: 11), cornerRadius: 3),
            with: .color(color(0x8FB8F0)))
        for x in stride(from: 74.0, through: 102, by: 6) {
            context.fill(
                Path(ellipse: CGPoint(x: x, y: floorLine - 6.5), rx: 1.2, ry: 1.2), with: .color(.white.opacity(0.7)))
        }
    }
}

enum LivingRoom {
    static func draw(_ context: GraphicsContext, height: CGFloat, world: SceneWorld) {
        room(context, height: height, wall: 0xFFE3CC, floor: 0xD9A877, planks: 0xB98656)
        Props.tinyDoor(context, at: CGPoint(x: 15, y: floorLine), world: world)
        // Framed pictures.
        for (rect, art) in [
            (CGRect(x: 36, y: 8, width: 14, height: 11), 0x9FD8B8),
            (CGRect(x: 54, y: 12, width: 10, height: 8), 0xF7B2A6),
        ] {
            context.fill(
                Path(roundedRect: rect.insetBy(dx: -1.4, dy: -1.4), cornerRadius: 1.5), with: .color(color(0x8C6B4F)))
            context.fill(Path(rect), with: .color(color(UInt32(art))))
        }
        sofa(context)
        plant(context, base: CGPoint(x: 90, y: floorLine), sway: world.wave(0.7))
        // A floor lamp on the left.
        context.fill(Path(CGRect(x: 9.3, y: floorLine - 34, width: 1.4, height: 34)), with: .color(color(0x5E5560)))
        context.fill(
            Path(roundedRect: CGRect(x: 4, y: floorLine - 42, width: 12, height: 9), cornerRadius: 3),
            with: .color(color(0xFFF0C2)))
        rug(context, fill: 0xA8C8E8, trim: 0xFFFFFF)
    }

    /// The floor lamp's shade, for its glow at night.
    static let lamp = CGPoint(x: 10, y: floorLine - 37)

    private static func sofa(_ context: GraphicsContext) {
        let body = color(0xE8836B)
        context.fill(
            Path(roundedRect: CGRect(x: 22, y: floorLine - 26, width: 56, height: 16), cornerRadius: 6),
            with: .color(body))
        context.fill(
            Path(roundedRect: CGRect(x: 20, y: floorLine - 13, width: 60, height: 11), cornerRadius: 4),
            with: .color(color(0xD96E57)))
        for x in [18.0, 74] {
            context.fill(
                Path(roundedRect: CGRect(x: x, y: floorLine - 18, width: 8, height: 16), cornerRadius: 4),
                with: .color(body))
        }
        for x in [34.0, 58] {
            context.fill(
                Path(roundedRect: CGRect(x: x, y: floorLine - 22, width: 9, height: 8), cornerRadius: 3),
                with: .color(color(0xFFD27A)))
        }
        for x in [24.0, 74] {
            context.fill(Path(CGRect(x: x, y: floorLine - 2, width: 2, height: 2.5)), with: .color(color(0x6B4A36)))
        }
    }

    static func plant(_ context: GraphicsContext, base: CGPoint, sway: Double) {
        for (index, (start, length)) in [(-115.0, 14.0), (-90, 18), (-65, 14), (-140, 10), (-40, 10)].enumerated() {
            let angle = start + sway * (2 + Double(index % 3))
            let radians = angle * .pi / 180
            let tip = CGPoint(x: base.x + cos(radians) * length, y: base.y - 8 + sin(radians) * length)
            context.fill(
                Path(
                    ellipse: CGPoint(x: (base.x + tip.x) / 2, y: (base.y - 8 + tip.y) / 2), rx: 2.6, ry: length / 2,
                    degrees: angle + 90),
                with: .color(color(0x4FA36A)))
        }
        context.fill(
            Path(roundedRect: CGRect(x: base.x - 5, y: base.y - 9, width: 10, height: 9), cornerRadius: 2),
            with: .color(color(0xD98E5F)))
    }
}

enum Kitchen {
    static func draw(_ context: GraphicsContext, height: CGFloat, world: SceneWorld) {
        context.fill(Path(CGRect(x: 0, y: 0, width: 100, height: floorLine)), with: .color(color(0xD7F0E6)))
        // Checkerboard floor.
        let tile: CGFloat = 8
        for row in 0..<Int((height - floorLine) / tile + 1) {
            for column in 0..<13 {
                let light = (row + column).isMultiple(of: 2)
                context.fill(
                    Path(
                        CGRect(x: CGFloat(column) * tile, y: floorLine + CGFloat(row) * tile, width: tile, height: tile)
                    ),
                    with: .color(color(light ? 0xFFFFFF : 0xF2C9C9)))
            }
        }
        window(context, frame: CGRect(x: 41, y: 8, width: 18, height: 14), curtain: 0xFFB7A8, world: world)
        // Counters with a tiled backsplash, cupboards and a fridge.
        for x in stride(from: 0.0, through: 100, by: 5) {
            var grout = Path()
            grout.move(to: CGPoint(x: x, y: 26))
            grout.addLine(to: CGPoint(x: x, y: floorLine - 20))
            context.stroke(grout, with: .color(.white.opacity(0.6)), lineWidth: 0.5)
        }
        for (start, width) in [(0.0, 30.0), (70, 30)] {
            context.fill(
                Path(CGRect(x: start, y: floorLine - 20, width: width, height: 2.5)), with: .color(color(0xF4EDE4)))
            context.fill(
                Path(CGRect(x: start, y: floorLine - 17.5, width: width, height: 17.5)), with: .color(color(0x7FB8A6)))
            for door in stride(from: start + 1.5, to: start + width - 1, by: 9.5) {
                context.stroke(
                    Path(roundedRect: CGRect(x: door, y: floorLine - 15.5, width: 8, height: 13), cornerRadius: 1),
                    with: .color(.white.opacity(0.55)), lineWidth: 0.8)
                context.fill(
                    Path(ellipse: CGPoint(x: door + 6.5, y: floorLine - 9), rx: 0.7, ry: 0.7), with: .color(.white))
            }
        }
        // A kettle and a fruit bowl on the counters.
        context.fill(Path(ellipse: CGPoint(x: 14, y: floorLine - 24), rx: 4, ry: 3.5), with: .color(color(0xFF8A6B)))
        if world.time > 0 { steam(context, from: CGPoint(x: 16.5, y: floorLine - 28), world: world) }
        for (x, fruit) in [(80.0, 0xFFC94D), (84.5, 0xE8524A), (89, 0x8BC34A)] {
            context.fill(
                Path(ellipse: CGPoint(x: x, y: floorLine - 22.5), rx: 2.4, ry: 2.4), with: .color(color(UInt32(fruit))))
        }
        context.fill(Path(ellipse: CGPoint(x: 84.5, y: floorLine - 21), rx: 7, ry: 2), with: .color(color(0xC9A27A)))
        Props.floorBowl(context, at: CGPoint(x: 24, y: floorLine + 10))
    }

    /// Wisps of steam curling up from the kettle.
    static func steam(_ context: GraphicsContext, from spout: CGPoint, world: SceneWorld) {
        for index in 0..<2 {
            let rise = world.cycle(3.2, offset: Double(index) * 0.5)
            var wisp = Path()
            let bottom = CGPoint(x: spout.x, y: spout.y - rise * 10)
            wisp.move(to: bottom)
            wisp.addCurve(
                to: CGPoint(x: bottom.x + 1, y: bottom.y - 6), control1: CGPoint(x: bottom.x + 2.5, y: bottom.y - 2),
                control2: CGPoint(x: bottom.x - 2, y: bottom.y - 4))
            context.stroke(
                wisp, with: .color(.white.opacity(0.75 * sin(.pi * rise))),
                style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
        }
    }

    /// Warm light along the backsplash over the counters once it's dark.
    static func underCounterLights(_ context: GraphicsContext, world: SceneWorld) {
        let night = world.light.night
        guard night > 0.02 else { return }
        let glow = Color(red: 1, green: 0.88, blue: 0.6)
        for (start, width) in [(0.0, 30.0), (70, 30)] {
            let rect = CGRect(x: start, y: floorLine - 32, width: width, height: 12)
            context.fill(
                Path(rect),
                with: .linearGradient(
                    Gradient(colors: [glow.opacity(0.5 * night), .clear]), startPoint: CGPoint(x: 0, y: rect.minY),
                    endPoint: CGPoint(x: 0, y: rect.maxY)))
        }
    }
}

/// A playroom: bunting across the wall, a window, a shelf of toys with a moon night-light, a
/// tower of letter blocks and a round play mat.
enum Playroom {
    static func draw(_ context: GraphicsContext, height: CGFloat, world: SceneWorld) {
        room(context, height: height, wall: 0xD6F1EA, floor: 0xEBCB9F, planks: 0xCCA57A)
        bunting(context, world: world)
        window(context, frame: CGRect(x: 40, y: 16, width: 20, height: 18), curtain: 0xFFB3C7, world: world)
        shelf(context)
        blocks(context, base: CGPoint(x: 12, y: floorLine))
        // A round play mat with a rainbow ring.
        let mat = Path(ellipse: CGPoint(x: 50, y: floorLine + 22), rx: 32, ry: 9)
        context.fill(mat, with: .color(color(0xFFF3C4)))
        for (inset, hex) in [(2.0, 0xFF9EAE), (4, 0xFFD27A), (6, 0x9ED9B8)] {
            context.stroke(
                Path(ellipse: CGPoint(x: 50, y: floorLine + 22), rx: 32 - inset * 1.4, ry: 9 - inset * 0.4),
                with: .color(color(UInt32(hex))), lineWidth: 1)
        }
        ball(context, at: CGPoint(x: 86, y: floorLine + 12))
    }

    /// The moon night-light on the shelf, for its glow at night.
    static let lamp = CGPoint(x: 84, y: floorLine - 33)

    /// Little flags strung across the top of the wall, swaying gently.
    private static func bunting(_ context: GraphicsContext, world: SceneWorld) {
        var string = Path()
        string.move(to: CGPoint(x: 0, y: 5))
        string.addQuadCurve(to: CGPoint(x: 100, y: 5), control: CGPoint(x: 50, y: 14))
        context.stroke(string, with: .color(color(0x9C8A7A)), lineWidth: 0.5)
        let colours: [UInt32] = [0xFF7B8E, 0xFFD24D, 0x6FC3E8, 0x8ED39A, 0xC59CF0]
        for index in 0..<9 {
            let along = (CGFloat(index) + 0.5) / 9
            let x = along * 100
            // The string's height at x (the same curve as above).
            let y = 5 + 2 * along * (1 - along) * 9
            let sway = CGFloat(world.sway(1.1, Double(index) * 0.9)) * 0.8
            let flag = Path(
                roundedPolygon: [
                    CGPoint(x: x - 3, y: y), CGPoint(x: x + 3, y: y), CGPoint(x: x + sway, y: y + 6),
                ], radius: 0.5)
            context.fill(flag, with: .color(color(colours[index % colours.count])))
        }
    }

    /// A shelf on the right wall with toys and the moon night-light.
    private static func shelf(_ context: GraphicsContext) {
        let wood = color(0xC08B5C)
        for y in [floorLine - 29, floorLine - 14] {
            context.fill(Path(CGRect(x: 72, y: y, width: 28, height: 2)), with: .color(wood))
        }
        context.fill(Path(CGRect(x: 72, y: floorLine - 29, width: 1.6, height: 29)), with: .color(wood))
        // Top shelf: the night-light and a little stack of books.
        context.fill(Path(ellipse: lamp, rx: 3.2, ry: 3.2), with: .color(color(0xFFE9A0)))
        context.fill(
            Path(ellipse: CGPoint(x: lamp.x + 1.6, y: lamp.y - 1), rx: 2.6, ry: 2.6), with: .color(color(0xD6F1EA)))
        for (index, hex) in [0xE5484D, 0x4FA3E0, 0x8ED39A].enumerated() {
            context.fill(
                Path(CGRect(x: 90 + CGFloat(index) * 2.4, y: floorLine - 37, width: 2, height: 8)),
                with: .color(color(UInt32(hex))))
        }
        // Bottom shelf: a teddy and a toy car.
        let bear = color(0xB98656)
        context.fill(Path(ellipse: CGPoint(x: 80, y: floorLine - 18), rx: 3.4, ry: 3.6), with: .color(bear))
        context.fill(Path(ellipse: CGPoint(x: 80, y: floorLine - 23), rx: 2.6, ry: 2.5), with: .color(bear))
        for side in [-1.0, 1] {
            context.fill(
                Path(ellipse: CGPoint(x: 80 + side * 2, y: floorLine - 25.2), rx: 1, ry: 1), with: .color(bear))
        }
        context.fill(
            Path(roundedRect: CGRect(x: 88, y: floorLine - 20, width: 9, height: 4), cornerRadius: 1.5),
            with: .color(color(0xFF7B8E)))
        for x in [90.0, 95] {
            context.fill(
                Path(ellipse: CGPoint(x: x, y: floorLine - 15.6), rx: 1.2, ry: 1.2), with: .color(color(0x3A3440)))
        }
    }

    /// A tower of letter blocks.
    private static func blocks(_ context: GraphicsContext, base: CGPoint) {
        let stack: [(CGPoint, UInt32)] = [
            (CGPoint(x: -5, y: 0), 0xFF7B8E), (CGPoint(x: 1, y: 0), 0x6FC3E8), (CGPoint(x: -2, y: -6), 0xFFD24D),
        ]
        for (offset, hex) in stack {
            let rect = CGRect(x: base.x + offset.x, y: base.y + offset.y - 6, width: 6, height: 6)
            context.fill(Path(roundedRect: rect, cornerRadius: 0.8), with: .color(color(hex)))
            context.stroke(
                Path(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 0.5), with: .color(.white.opacity(0.7)),
                lineWidth: 0.5)
        }
    }

    private static func ball(_ context: GraphicsContext, at center: CGPoint) {
        let ball = Path(ellipse: center, rx: 3.6, ry: 3.6)
        context.fill(ball, with: .color(color(0x6FC3E8)))
        var band = context
        band.clip(to: ball)
        band.fill(Path(CGRect(x: center.x - 4, y: center.y - 1, width: 8, height: 2)), with: .color(.white))
        context.fill(
            Path(ellipse: CGPoint(x: center.x, y: center.y + 3.6), rx: 3.4, ry: 0.7), with: .color(.black.opacity(0.1)))
    }
}
