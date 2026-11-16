import SwiftUI

// Hand-placed things that make each scene somebody's place: a signpost, a dock, a campfire, a
// snowman, a tiny door in the skirting board. Same 100-wide art space as the scenes; `base` is
// where a thing meets the ground.

private func color(_ hex: UInt32) -> Color { PetColor(hex: hex).color }

enum Props {
    /// A wooden signpost with two arrows pointing the way to adventure.
    static func signpost(_ context: GraphicsContext, at base: CGPoint) {
        let wood = color(0xA5774D)
        let dark = color(0x7A5638)
        context.fill(
            Path(roundedRect: CGRect(x: base.x - 1.2, y: base.y - 22, width: 2.4, height: 22), cornerRadius: 1),
            with: .color(dark))
        for (y, flip) in [(base.y - 20.5, 1.0), (base.y - 14.5, -1.0)] {
            let sign = Path(
                roundedPolygon: [
                    CGPoint(x: base.x - 7 * flip, y: y), CGPoint(x: base.x + 6 * flip, y: y),
                    CGPoint(x: base.x + 9 * flip, y: y + 2.2), CGPoint(x: base.x + 6 * flip, y: y + 4.4),
                    CGPoint(x: base.x - 7 * flip, y: y + 4.4),
                ], radius: 0.6)
            context.fill(sign, with: .color(wood))
            context.stroke(sign, with: .color(dark), lineWidth: 0.5)
            for dash in 0..<3 {
                context.fill(
                    Path(CGRect(x: base.x - 4.5 + CGFloat(dash) * 3, y: y + 1.7, width: 2, height: 1)),
                    with: .color(dark.opacity(0.7)))
            }
        }
    }

    /// A fallen log, mossy on top.
    static func log(_ context: GraphicsContext, at base: CGPoint) {
        let bark = color(0x8C6239)
        context.fill(
            Path(roundedRect: CGRect(x: base.x - 9, y: base.y - 5.5, width: 18, height: 5.5), cornerRadius: 2.6),
            with: .color(bark))
        context.fill(
            Path(roundedRect: CGRect(x: base.x - 9, y: base.y - 5.5, width: 18, height: 1.6), cornerRadius: 0.8),
            with: .color(color(0x6FAE5C).opacity(0.8)))
        let end = CGPoint(x: base.x + 9, y: base.y - 2.75)
        context.fill(Path(ellipse: end, rx: 1.9, ry: 2.75), with: .color(color(0xD9B48A)))
        context.stroke(Path(ellipse: end, rx: 1, ry: 1.5), with: .color(bark.opacity(0.6)), lineWidth: 0.4)
        context.fill(
            Path(ellipse: CGPoint(x: base.x - 3, y: base.y - 2.5), rx: 1.1, ry: 0.8), with: .color(color(0x6B4A2E)))
    }

    /// A few planks of a wooden dock reaching into the water from the left bank.
    static func dock(_ context: GraphicsContext, at y: CGFloat) {
        let wood = color(0xB8865A)
        for post in [4.0, 15] {
            context.fill(Path(CGRect(x: post, y: y + 1, width: 1.6, height: 5)), with: .color(color(0x8C6239)))
        }
        context.fill(
            Path(roundedRect: CGRect(x: -2, y: y - 2.5, width: 21, height: 4.2), cornerRadius: 1), with: .color(wood))
        for seam in stride(from: 2.0, to: 19, by: 3.5) {
            context.fill(
                Path(CGRect(x: seam, y: y - 2.5, width: 0.5, height: 4.2)), with: .color(color(0x8C6239).opacity(0.6)))
        }
    }

    /// A little frog sitting on a lily pad, blinking now and then.
    static func frog(_ context: GraphicsContext, at center: CGPoint, world: SceneWorld) {
        let green = color(0x5DB36A)
        context.fill(Path(ellipse: CGPoint(x: center.x, y: center.y - 1.2), rx: 2.8, ry: 1.9), with: .color(green))
        let blink = world.time > 0 && world.cycle(5.3) < 0.05
        for side in [-1.0, 1] {
            let eye = CGPoint(x: center.x + side * 1.5, y: center.y - 3)
            context.fill(Path(ellipse: eye, rx: 0.95, ry: blink ? 0.3 : 0.95), with: .color(.white))
            if !blink {
                context.fill(Path(ellipse: eye, rx: 0.45, ry: 0.45), with: .color(color(0x2A1A33)))
            }
        }
    }

    /// A big tree trunk framing the left edge, roots flaring at the ground.
    static func treeTrunk(_ context: GraphicsContext, ground: CGFloat, height: CGFloat) {
        var trunk = Path()
        trunk.move(to: CGPoint(x: -4, y: -2))
        trunk.addLine(to: CGPoint(x: 9, y: -2))
        trunk.addCurve(
            to: CGPoint(x: 14, y: ground + 2), control1: CGPoint(x: 7, y: ground * 0.5),
            control2: CGPoint(x: 9, y: ground - 6))
        trunk.addQuadCurve(to: CGPoint(x: 2, y: ground + 4), control: CGPoint(x: 8, y: ground + 5))
        trunk.addLine(to: CGPoint(x: -4, y: ground + 4))
        trunk.closeSubpath()
        context.fill(trunk, with: .color(color(0x6B4A2E)))
        var shade = context
        shade.clip(to: trunk)
        shade.fill(Path(CGRect(x: 5, y: -2, width: 12, height: height + 4)), with: .color(.black.opacity(0.14)))
        for y in stride(from: 10.0, to: ground - 8, by: 11) {
            var bark = Path()
            bark.move(to: CGPoint(x: 1, y: y))
            bark.addQuadCurve(to: CGPoint(x: 6, y: y + 5), control: CGPoint(x: 2, y: y + 4))
            context.stroke(
                bark, with: .color(.black.opacity(0.18)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        }
    }

    /// A tree stump with its rings showing.
    static func stump(_ context: GraphicsContext, at base: CGPoint) {
        context.fill(
            Path(roundedRect: CGRect(x: base.x - 6, y: base.y - 7, width: 12, height: 7), cornerRadius: 1.5),
            with: .color(color(0x8C6239)))
        let top = CGPoint(x: base.x, y: base.y - 7)
        context.fill(Path(ellipse: top, rx: 6.5, ry: 2.6), with: .color(color(0xD9B48A)))
        for ring in [1.5, 3, 4.5] {
            context.stroke(
                Path(ellipse: top, rx: ring, ry: ring * 0.4), with: .color(color(0xA5774D).opacity(0.7)), lineWidth: 0.4
            )
        }
    }

    /// A snowman with a carrot nose and a red scarf.
    static func snowman(_ context: GraphicsContext, at base: CGPoint) {
        let edge = color(0xB9CBE6)
        for (lift, radius) in [(5.0, 6.5), (14, 5), (22, 4)] {
            let ball = Path(ellipse: CGPoint(x: base.x, y: base.y - lift), rx: radius, ry: radius)
            context.fill(ball, with: .color(.white))
            context.stroke(ball, with: .color(edge), lineWidth: 0.7)
        }
        for side in [-1.0, 1] {
            var arm = Path()
            arm.move(to: CGPoint(x: base.x + side * 4, y: base.y - 15))
            arm.addLine(to: CGPoint(x: base.x + side * 11, y: base.y - 20))
            context.stroke(arm, with: .color(color(0x7A5638)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
        context.fill(
            Path(roundedRect: CGRect(x: base.x - 4.5, y: base.y - 19, width: 9, height: 2.4), cornerRadius: 1.2),
            with: .color(color(0xE5484D)))
        context.fill(
            Path(roundedRect: CGRect(x: base.x + 1.5, y: base.y - 19, width: 2.4, height: 5), cornerRadius: 1),
            with: .color(color(0xE5484D)))
        for x in [-1.5, 1.5] {
            context.fill(
                Path(ellipse: CGPoint(x: base.x + x, y: base.y - 23), rx: 0.6, ry: 0.6), with: .color(color(0x2A1A33)))
        }
        var carrot = Path()
        carrot.move(to: CGPoint(x: base.x, y: base.y - 22))
        carrot.addLine(to: CGPoint(x: base.x + 4, y: base.y - 21.3))
        carrot.addLine(to: CGPoint(x: base.x, y: base.y - 20.8))
        carrot.closeSubpath()
        context.fill(carrot, with: .color(color(0xFF8A3D)))
        for lift in [12.0, 14.5] {
            context.fill(
                Path(ellipse: CGPoint(x: base.x, y: base.y - lift), rx: 0.6, ry: 0.6), with: .color(color(0x2A1A33)))
        }
    }

    /// A wooden sled with red runners, left by the slope.
    static func sled(_ context: GraphicsContext, at base: CGPoint) {
        for y in [base.y - 1.0] {
            var runner = Path()
            runner.move(to: CGPoint(x: base.x - 9, y: y))
            runner.addLine(to: CGPoint(x: base.x + 7, y: y))
            runner.addQuadCurve(to: CGPoint(x: base.x + 10, y: y - 4), control: CGPoint(x: base.x + 10.5, y: y - 0.5))
            context.stroke(runner, with: .color(color(0xE5484D)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
        context.fill(
            Path(roundedRect: CGRect(x: base.x - 8, y: base.y - 5, width: 15, height: 2.6), cornerRadius: 1),
            with: .color(color(0xC9A27A)))
        for x in [-5.0, 0, 5] {
            context.fill(
                Path(CGRect(x: base.x + x, y: base.y - 2.6, width: 1, height: 1.8)), with: .color(color(0xE5484D)))
        }
    }

    /// A red bucket with a spade leaning on it.
    static func bucketAndSpade(_ context: GraphicsContext, at base: CGPoint) {
        var spade = Path()
        spade.move(to: CGPoint(x: base.x + 6, y: base.y - 1))
        spade.addLine(to: CGPoint(x: base.x + 11, y: base.y - 12))
        context.stroke(spade, with: .color(color(0xC9A27A)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        context.fill(
            Path(roundedRect: CGRect(x: base.x + 3.5, y: base.y - 4, width: 4.5, height: 5), cornerRadius: 1.2)
                .rotated(degrees: -24, around: CGPoint(x: base.x + 6, y: base.y - 1)),
            with: .color(color(0x4FA3E0)))
        let bucket = Path(
            roundedPolygon: [
                CGPoint(x: base.x - 6, y: base.y - 9), CGPoint(x: base.x + 4, y: base.y - 9),
                CGPoint(x: base.x + 3, y: base.y), CGPoint(x: base.x - 5, y: base.y),
            ], radius: 0.8)
        context.fill(bucket, with: .color(color(0xE5484D)))
        context.fill(
            Path(ellipse: CGPoint(x: base.x - 1, y: base.y - 9), rx: 5, ry: 1.2), with: .color(color(0xFF7B7B)))
        var handle = Path()
        handle.addArc(
            center: CGPoint(x: base.x - 1, y: base.y - 9), radius: 4.5, startAngle: .degrees(200),
            endAngle: .degrees(340), clockwise: false)
        context.stroke(handle, with: .color(color(0xFFD54D)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
    }

    /// A campfire: crossed logs, flames that flicker and sparks drifting up, with a warm glow.
    static func campfire(_ context: GraphicsContext, at base: CGPoint, world: SceneWorld) {
        let flicker = 0.8 + 0.2 * world.wave(9, 0.3) + 0.1 * world.wave(13.7)
        context.fill(
            Path(ellipse: base, rx: 30, ry: 30),
            with: .radialGradient(
                Gradient(colors: [color(0xFFB347).opacity(0.38 * flicker), color(0xFF8A3D).opacity(0.12), .clear]),
                center: base, startRadius: 0, endRadius: 30))
        for turn in [-22.0, 22] {
            context.fill(
                Path(roundedRect: CGRect(x: base.x - 8, y: base.y - 2.6, width: 16, height: 3), cornerRadius: 1.4)
                    .rotated(degrees: turn, around: CGPoint(x: base.x, y: base.y - 1)),
                with: .color(color(0x7A5638)))
        }
        for (index, (offset, size, hex)) in [(0.0, 11.0, 0xFF8A3D), (-2.5, 7.0, 0xFFB347), (2, 5.0, 0xFFE27A)]
            .enumerated()
        {
            let lick = size * (0.85 + 0.15 * world.wave(7 + Double(index) * 2, Double(index)))
            let sway = world.wave(5 + Double(index), Double(index) * 1.3) * 1.2
            var flame = Path()
            flame.move(to: CGPoint(x: base.x + offset - size * 0.35, y: base.y - 2))
            flame.addQuadCurve(
                to: CGPoint(x: base.x + offset + sway, y: base.y - 2 - lick),
                control: CGPoint(x: base.x + offset - size * 0.4, y: base.y - lick * 0.6))
            flame.addQuadCurve(
                to: CGPoint(x: base.x + offset + size * 0.35, y: base.y - 2),
                control: CGPoint(x: base.x + offset + size * 0.4, y: base.y - lick * 0.6))
            flame.closeSubpath()
            context.fill(flame, with: .color(color(UInt32(hex))))
        }
        guard world.time > 0 else { return }
        for spark in 0..<3 {
            let rise = world.cycle(2.1 + Double(spark) * 0.4, offset: Double(spark) * 0.33)
            let point = CGPoint(x: base.x + sin(rise * 9 + Double(spark)) * 3, y: base.y - 8 - rise * 18)
            context.fill(Path(ellipse: point, rx: 0.7, ry: 0.7), with: .color(color(0xFFE27A).opacity(1 - rise)))
        }
    }

    /// A tiny door low in the skirting board. Who knows where it goes. A sliver of light shows
    /// under it once the room is dark.
    static func tinyDoor(_ context: GraphicsContext, at base: CGPoint, world: SceneWorld) {
        let width: CGFloat = 4.4
        let height: CGFloat = 7
        var door = Path()
        door.move(to: CGPoint(x: base.x - width / 2, y: base.y))
        door.addLine(to: CGPoint(x: base.x - width / 2, y: base.y - height + width / 2))
        door.addArc(
            center: CGPoint(x: base.x, y: base.y - height + width / 2), radius: width / 2, startAngle: .degrees(180),
            endAngle: .degrees(0), clockwise: false)
        door.addLine(to: CGPoint(x: base.x + width / 2, y: base.y))
        door.closeSubpath()
        context.fill(
            door.applying(CGAffineTransform(translationX: 0, y: 0)).strokedPath(StrokeStyle(lineWidth: 1.4)),
            with: .color(color(0x6B4A2E)))
        context.fill(door, with: .color(color(0xB05A3C)))
        context.fill(
            Path(ellipse: CGPoint(x: base.x + 1.2, y: base.y - 3), rx: 0.5, ry: 0.5), with: .color(color(0xFFD54D)))
        let night = world.light.night
        if night > 0.05 {
            context.fill(
                Path(CGRect(x: base.x - width / 2, y: base.y - 0.4, width: width, height: 0.6)),
                with: .color(color(0xFFE9A0).opacity(0.9 * night)))
        }
    }

    /// A food bowl on the floor, the same one the pet eats from.
    static func floorBowl(_ context: GraphicsContext, at base: CGPoint) {
        var inner = context
        inner.translateBy(x: base.x - 6, y: base.y - 10)
        inner.scaleBy(x: 0.12, y: 0.12)
        IconArt.bowl(Ink(context: inner))
    }
}
