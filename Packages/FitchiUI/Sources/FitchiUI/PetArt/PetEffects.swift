import SwiftUI

/// Things drawn around a pet that show how it feels or what it's doing: Zzz, stink lines, a
/// thought bubble, hearts and care props. Drawn in the same 100×100 art space as the pet.
public struct PetEffects: Hashable, Sendable {
    /// Seconds, driving the looping effects (rising Zzz, wafting stink lines).
    public var clock: Double = 0
    public var zzz = false
    public var stink = false
    public var smudges = false
    public var sweat = false
    /// An emoji in a thought bubble ("I want food").
    public var thought: String?
    /// A puff of hearts, 0…1 through its rise.
    public var hearts: Double?
    public var prop: Prop?
    /// Puddle water splashing up round the feet, 0…1.
    public var splash: Double?
    /// A burst of confetti, 0…1 through its fall.
    public var confetti: Double?

    /// Care props, each with its own progress.
    public enum Prop: Hashable, Sendable {
        /// A food bowl in front of the pet, emptied as `eaten` goes 0 → 1.
        case bowl(eaten: Double)
        /// A bouncing ball at a point in art space.
        case ball(CGPoint)
        /// Bath bubbles rising and popping, 0…1.
        case bubbles(Double)
        /// Squeaky-clean twinkles, 0…1.
        case sparkle(Double)
    }

    public init() {}

    public static let none = PetEffects()
}

/// Drawing for `PetEffects`. "Body" effects ride along with the pet's pose; the rest float in
/// the scene around it.
enum EffectArt {
    static let ink = PetColor(hex: 0x2A1A33)

    /// Marks on the pet itself (call with the posed context).
    static func drawOnBody(_ effects: PetEffects, _ context: GraphicsContext) {
        if effects.smudges {
            let mud = Color(red: 0.45, green: 0.33, blue: 0.22).opacity(0.38)
            for (center, size) in [
                (CGPoint(x: 40, y: 82), 3.6), (CGPoint(x: 61, y: 74), 3.0), (CGPoint(x: 64, y: 36), 2.6),
            ] {
                context.fill(Path(ellipse: center, rx: size, ry: size * 0.75, degrees: 20), with: .color(mud))
                context.fill(
                    Path(ellipse: CGPoint(x: center.x + size, y: center.y + 1), rx: size * 0.5, ry: size * 0.4),
                    with: .color(mud))
            }
        }
        if effects.sweat {
            let drop = sweatDrop(at: CGPoint(x: 80, y: 34 + sin(effects.clock * 3) * 1.2))
            context.stroke(drop, with: .color(ink.color.opacity(0.7)), lineWidth: 1.4)
            context.fill(drop, with: .color(Color(red: 0.62, green: 0.85, blue: 1)))
        }
    }

    /// Effects around the pet. `flipped` moves the thought bubble behind the pet's head.
    static func drawAround(_ effects: PetEffects, _ context: GraphicsContext, flipped: Bool) {
        if effects.stink { stink(context, clock: effects.clock) }
        if effects.zzz { zzz(context, clock: effects.clock, flipped: flipped) }
        if let thought = effects.thought { thoughtBubble(context, emoji: thought, flipped: flipped) }
        if let hearts = effects.hearts { self.hearts(context, progress: hearts) }
        if let splash = effects.splash { self.splash(context, progress: splash) }
        if let confetti = effects.confetti { self.confetti(context, progress: confetti) }
        switch effects.prop {
        case .bowl(let eaten): bowl(context, eaten: eaten)
        case .ball(let point): ball(context, at: point)
        case .bubbles(let progress): bubbles(context, progress: progress)
        case .sparkle(let progress): sparkle(context, progress: progress)
        case nil: break
        }
    }

    // MARK: - Moods

    private static func zzz(_ context: GraphicsContext, clock: Double, flipped: Bool) {
        let side: Double = flipped ? -1 : 1
        for index in 0..<3 {
            let phase = ((clock + Double(index) * 0.9) / 2.7).truncatingRemainder(dividingBy: 1)
            let point = CGPoint(x: 50 + side * (14 + phase * 20), y: 40 - phase * 34)
            let size = 9 + phase * 7
            let fade = sin(.pi * phase)
            // A dark outline behind each letter keeps it readable over sky and grass.
            for (shiftX, shiftY) in [(-0.8, 0.0), (0.8, 0), (0, -0.8), (0, 0.8)] {
                let outline = Text("z").font(.system(size: size, weight: .black, design: .rounded))
                    .foregroundStyle(ink.color.opacity(0.8 * fade))
                context.draw(outline, at: CGPoint(x: point.x + shiftX, y: point.y + shiftY))
            }
            let letter = Text("z")
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.8, green: 0.78, blue: 1).opacity(fade))
            context.draw(letter, at: point)
        }
    }

    private static func stink(_ context: GraphicsContext, clock: Double) {
        let fume = Color(red: 0.62, green: 0.8, blue: 0.2)
        for (index, baseX) in [16.0, 84, 26].enumerated() {
            let phase = ((clock + Double(index) * 0.7) / 2.1).truncatingRemainder(dividingBy: 1)
            var wave = Path()
            let bottom = 62 - phase * 24
            wave.move(to: CGPoint(x: baseX, y: bottom))
            for step in 1...6 {
                let y = bottom - Double(step) * 2.6
                wave.addLine(to: CGPoint(x: baseX + sin(Double(step) * 1.4 + clock * 4) * 2.2, y: y))
            }
            let fade = sin(.pi * phase)
            context.stroke(
                wave, with: .color(ink.color.opacity(0.75 * fade)),
                style: StrokeStyle(lineWidth: 4.4, lineCap: .round, lineJoin: .round))
            context.stroke(
                wave, with: .color(fume.opacity(fade)),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }
    }

    private static func thoughtBubble(_ context: GraphicsContext, emoji: String, flipped: Bool) {
        let side: Double = flipped ? -1 : 1
        let center = CGPoint(x: 50 + side * 33, y: 13)
        let puffs = [
            (CGPoint(x: 50 + side * 22, y: 31), 1.8), (CGPoint(x: 50 + side * 26, y: 25), 2.6), (center, 11.0),
        ]
        for (point, radius) in puffs {
            let circle = Path(ellipse: point, rx: radius, ry: radius * (radius > 5 ? 0.85 : 1))
            context.stroke(circle, with: .color(ink.color.opacity(0.8)), lineWidth: 2.2)
            context.fill(circle, with: .color(.white))
        }
        context.draw(Text(emoji).font(.system(size: 11)), at: CGPoint(x: center.x, y: center.y + 0.5))
    }

    private static func hearts(_ context: GraphicsContext, progress: Double) {
        let pink = Color(red: 1, green: 0.42, blue: 0.6)
        for (index, offset) in [-14.0, 2, 16].enumerated() {
            let rise = min(1, max(0, progress * 1.3 - Double(index) * 0.15))
            let point = CGPoint(x: 50 + offset * 1.4 + sin(rise * 6) * 2, y: 24 - rise * 22)
            let fade = rise > 0 ? min(1, (1 - rise) * 2) : 0
            let size = 12 + rise * 5
            let outline = Text("♥").font(.system(size: size + 3, weight: .black)).foregroundStyle(.white.opacity(fade))
            context.draw(outline, at: point)
            let heart = Text("♥").font(.system(size: size, weight: .heavy)).foregroundStyle(pink.opacity(fade))
            context.draw(heart, at: point)
        }
    }

    private static func sweatDrop(at point: CGPoint) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: point.x, y: point.y - 4.5))
        path.addQuadCurve(
            to: CGPoint(x: point.x + 2.8, y: point.y + 1.2), control: CGPoint(x: point.x + 2.8, y: point.y - 1))
        path.addArc(
            center: CGPoint(x: point.x, y: point.y + 1.2), radius: 2.8, startAngle: .zero, endAngle: .degrees(180),
            clockwise: false)
        path.addQuadCurve(to: CGPoint(x: point.x, y: point.y - 4.5), control: CGPoint(x: point.x - 2.8, y: point.y - 1))
        return path
    }

    // MARK: - Care props

    private static func bowl(_ context: GraphicsContext, eaten: Double) {
        let ink = Ink(context: context)
        // Food mound, shrinking as it's eaten.
        let left = max(0, 1 - eaten)
        if left > 0.02 {
            let food = Tone(PetColor(hex: 0xC98A4B))
            for (offset, radius) in [(-6.0, 4.2), (0, 5.0), (6, 4.2), (-3, 3.6), (3, 3.6)] {
                let lift = radius == 3.6 ? 3.5 : 0
                ink.part(
                    Path(
                        ellipse: CGPoint(x: 50 + offset, y: 82 - (lift + 2) * left), rx: (radius + 1) * left,
                        ry: (radius + 1) * 0.8 * left),
                    food, shaded: false, outlined: true)
            }
        }
        var dish = Path()
        dish.move(to: CGPoint(x: 34, y: 85))
        dish.addLine(to: CGPoint(x: 66, y: 85))
        dish.addQuadCurve(to: CGPoint(x: 60, y: 96), control: CGPoint(x: 65, y: 95))
        dish.addLine(to: CGPoint(x: 40, y: 96))
        dish.addQuadCurve(to: CGPoint(x: 34, y: 85), control: CGPoint(x: 35, y: 95))
        dish.closeSubpath()
        ink.part(dish, Tone(PetColor(hex: 0xFF6B6B)), gloss: true)
        ink.part(Path(ellipse: CGPoint(x: 50, y: 85), rx: 16, ry: 2.6), Tone(PetColor(hex: 0xFF8A8A)), shaded: false)
    }

    private static func ball(_ context: GraphicsContext, at point: CGPoint) {
        let height = max(0, 92 - point.y)
        let shrink = max(0.4, 1 - height / 50)
        context.fill(
            Path(ellipse: CGPoint(x: point.x, y: 94), rx: 6 * shrink, ry: 1.6 * shrink),
            with: .color(.black.opacity(0.18)))
        let ink = Ink(context: context)
        let ball = Path(ellipse: point, rx: 6, ry: 6)
        ink.part(ball, Tone(PetColor(hex: 0xD7F24B)), gloss: true)
        var seam = Path()
        seam.move(to: CGPoint(x: point.x - 5, y: point.y - 2))
        seam.addQuadCurve(to: CGPoint(x: point.x + 5, y: point.y - 2), control: CGPoint(x: point.x, y: point.y + 4))
        ink.line(seam, .white.opacity(0.9), width: 1.3)
    }

    private struct Bubble {
        let x: Double
        let y: Double
        let radius: Double
        let speed: Double
    }

    private static let bubbleSpots = [
        Bubble(x: 24, y: 80, radius: 4.5, speed: 1.0), Bubble(x: 34, y: 62, radius: 3.2, speed: 1.3),
        Bubble(x: 70, y: 66, radius: 5, speed: 0.9), Bubble(x: 80, y: 84, radius: 3.4, speed: 1.2),
        Bubble(x: 50, y: 58, radius: 3.8, speed: 1.1), Bubble(x: 42, y: 88, radius: 3, speed: 1.4),
        Bubble(x: 62, y: 86, radius: 4, speed: 1.0), Bubble(x: 16, y: 64, radius: 2.6, speed: 1.5),
        Bubble(x: 86, y: 58, radius: 3, speed: 1.25),
    ]

    private static func bubbles(_ context: GraphicsContext, progress: Double) {
        for (index, spot) in bubbleSpots.enumerated() {
            let local = min(1, max(0, progress * 1.4 - Double(index) * 0.05))
            guard local > 0, local < 1 else { continue }
            let center = CGPoint(x: spot.x + sin(local * 7 + Double(index)) * 2, y: spot.y - local * 30 * spot.speed)
            let radius = spot.radius * (0.6 + local * 0.6)
            let bubble = Path(ellipse: center, rx: radius, ry: radius)
            let fade = local > 0.85 ? (1 - local) / 0.15 : 1
            context.fill(bubble, with: .color(Color(red: 0.8, green: 0.93, blue: 1).opacity(0.35 * fade)))
            context.stroke(bubble, with: .color(Color(red: 0.5, green: 0.75, blue: 0.95).opacity(fade)), lineWidth: 1.2)
            context.fill(
                Path(
                    ellipse: CGPoint(x: center.x - radius * 0.35, y: center.y - radius * 0.35), rx: radius * 0.3,
                    ry: radius * 0.22),
                with: .color(.white.opacity(fade)))
        }
    }

    private static func sparkle(_ context: GraphicsContext, progress: Double) {
        let size = sin(.pi * min(max(progress, 0), 1))
        for (point, base) in [(CGPoint(x: 24, y: 40), 5.0), (CGPoint(x: 78, y: 30), 6), (CGPoint(x: 72, y: 72), 4)] {
            context.fill(
                Sparkles.star(at: point, size: base * size), with: .color(Color(red: 1, green: 0.95, blue: 0.6)))
            context.fill(Sparkles.star(at: point, size: base * size * 0.45), with: .color(.white))
        }
    }
}
