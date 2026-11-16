import SwiftUI

/// Drawings for the needs: each one looks different at a glance, so you can tell what the pet
/// wants from across the room. On-body parts ride with the pose; the rest float around it.
extension EffectArt {
    static func drawNeedsOnBody(_ effects: PetEffects, _ context: GraphicsContext) {
        if let rumble = effects.rumble, rumble > 0.02 { self.rumble(context, intensity: rumble, clock: effects.clock) }
        if effects.queasy { queasy(context) }
        if effects.thermometer { thermometer(context) }
    }

    static func drawNeedsAround(_ effects: PetEffects, _ context: GraphicsContext) {
        if let scuff = effects.scuff { self.scuff(context, progress: scuff) }
        if effects.suitcase { suitcase(context) }
        if let clock = effects.raincloud { raincloud(context, clock: clock) }
        if let clock = effects.fly { fly(context, clock: clock) }
    }

    // MARK: - Hungry

    /// Wobbly lines either side of the belly: a tummy rumble.
    private static func rumble(_ context: GraphicsContext, intensity: Double, clock: Double) {
        for side in [-1.0, 1] {
            for row in 0..<3 {
                let x = 50 + side * (25 + Double(row) * 3.2)
                let top = 70 + Double(row) * 1.5
                var wave = Path()
                wave.move(to: CGPoint(x: x, y: top))
                for step in 1...4 {
                    let y = top + Double(step) * 3
                    let wobble = sin(Double(step) * 2.1 + clock * 14 + Double(row)) * 1.3 * intensity
                    wave.addLine(to: CGPoint(x: x + wobble, y: y))
                }
                let fade = intensity * (1 - Double(row) * 0.25)
                context.stroke(
                    wave, with: .color(ink.color.opacity(0.65 * fade)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }
        }
    }

    // MARK: - Sick

    /// A green tinge on the cheeks.
    private static func queasy(_ context: GraphicsContext) {
        let green = Color(red: 0.6, green: 0.84, blue: 0.55).opacity(0.55)
        for x in [31.0, 69] {
            context.fill(Path(ellipse: CGPoint(x: x, y: 56), rx: 5.8, ry: 3.6), with: .color(green))
        }
    }

    /// A thermometer poking out of the corner of its mouth.
    private static func thermometer(_ context: GraphicsContext) {
        let from = CGPoint(x: 56, y: 61)
        let tip = CGPoint(x: 73, y: 52)
        var tube = Path()
        tube.move(to: from)
        tube.addLine(to: tip)
        context.stroke(tube, with: .color(ink.color), style: StrokeStyle(lineWidth: 5.2, lineCap: .round))
        context.stroke(tube, with: .color(.white), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))
        var mercury = Path()
        mercury.move(to: CGPoint(x: from.x + 4, y: from.y - 2.1))
        mercury.addLine(to: CGPoint(x: tip.x - 2, y: tip.y + 1.1))
        context.stroke(
            mercury, with: .color(Color(red: 0.95, green: 0.25, blue: 0.3)),
            style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
        let bulb = Path(ellipse: CGPoint(x: tip.x + 0.5, y: tip.y - 0.3), rx: 2.8, ry: 2.8)
        context.stroke(bulb, with: .color(ink.color), lineWidth: 1.6)
        context.fill(bulb, with: .color(Color(red: 0.95, green: 0.25, blue: 0.3)))
    }

    // MARK: - Bored

    /// Dust kicked up by a scuffing front paw.
    private static func scuff(_ context: GraphicsContext, progress: Double) {
        let dust = Color(red: 0.93, green: 0.9, blue: 0.8)
        for (index, offset) in [(0, 4.0), (1, 9.0), (2, 14.0)] {
            let local = min(1, max(0, progress * 1.6 - Double(index) * 0.2))
            guard local > 0 else { continue }
            let center = CGPoint(x: 62 + offset * local, y: 92 - 4 * local - Double(index))
            context.fill(
                Path(ellipse: center, rx: 2.2 + 2 * local, ry: 1.8 + 1.4 * local),
                with: .color(dust.opacity(0.7 * (1 - local))))
        }
    }

    // MARK: - Packing

    /// A little suitcase waiting on the ground beside it.
    private static func suitcase(_ context: GraphicsContext) {
        let ink = Ink(context: context)
        let body = Path(roundedRect: CGRect(x: 80, y: 80, width: 17, height: 13), cornerRadius: 2.2)
        var handle = Path()
        handle.move(to: CGPoint(x: 85, y: 80))
        handle.addLine(to: CGPoint(x: 85.5, y: 76.5))
        handle.addLine(to: CGPoint(x: 91.5, y: 76.5))
        handle.addLine(to: CGPoint(x: 92, y: 80))
        context.stroke(handle, with: .color(Self.ink.color), style: StrokeStyle(lineWidth: 2.4, lineJoin: .round))
        ink.part(body, Tone(PetColor(hex: 0x9C6B3C)), gloss: true)
        context.fill(Path(CGRect(x: 80, y: 85, width: 17, height: 1.2)), with: .color(Self.ink.color.opacity(0.5)))
        for x in [83.5, 91.5] {
            context.fill(
                Path(roundedRect: CGRect(x: x, y: 84, width: 2.4, height: 3), cornerRadius: 0.6),
                with: .color(PetColor(hex: 0xFFD54D).color))
        }
    }

    // MARK: - Sad

    /// A small grey cloud raining on its head.
    private static func raincloud(_ context: GraphicsContext, clock: Double) {
        let center = CGPoint(x: 50, y: 6 + sin(clock * 1.1) * 0.8)
        var cloud = Path()
        for (shiftX, shiftY, radius) in [(-7.0, 2.0, 5.0), (0, -1, 6.5), (7, 2, 5), (0, 3, 6)] {
            cloud.addEllipse(
                in: CGRect(
                    x: center.x + shiftX - radius, y: center.y + shiftY - radius, width: radius * 2, height: radius * 2)
            )
        }
        context.stroke(cloud, with: .color(ink.color.opacity(0.75)), lineWidth: 2.2)
        context.fill(cloud, with: .color(Color(red: 0.62, green: 0.66, blue: 0.76)))
        for (index, x) in [41.0, 50, 59].enumerated() {
            let phase = (clock * 1.4 + Double(index) * 0.37).truncatingRemainder(dividingBy: 1)
            let drop = CGPoint(x: x, y: center.y + 9 + phase * 16)
            context.fill(
                Path(ellipse: drop, rx: 1.1, ry: 2),
                with: .color(Color(red: 0.45, green: 0.72, blue: 0.95).opacity(1 - phase * phase)))
        }
    }

    // MARK: - Dirty

    /// A fly buzzing in loops around its head, with a dotted trail.
    private static func fly(_ context: GraphicsContext, clock: Double) {
        func spot(_ angle: Double) -> CGPoint {
            CGPoint(x: 50 + cos(angle) * 31, y: 36 + sin(angle) * 9 + sin(angle * 3) * 3)
        }
        let angle = clock * 2.3
        for tail in 1...5 {
            let behind = spot(angle - Double(tail) * 0.22)
            context.fill(
                Path(ellipse: behind, rx: 0.8, ry: 0.8), with: .color(ink.color.opacity(0.35 * (1 - Double(tail) / 6))))
        }
        let here = spot(angle)
        let flap = abs(sin(clock * 42))
        for side in [-1.0, 1] {
            context.fill(
                Path(
                    ellipse: CGPoint(x: here.x + side * 1.6, y: here.y - 1.4), rx: 1.7, ry: 0.5 + 0.9 * flap,
                    degrees: side * -25),
                with: .color(.white.opacity(0.75)))
        }
        context.fill(Path(ellipse: here, rx: 1.9, ry: 1.3), with: .color(ink.color))
    }
}
