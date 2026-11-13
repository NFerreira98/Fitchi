import SwiftUI

extension EffectArt {
    /// Droplets jumping out of a puddle on either side of the feet (ground at y = 94).
    static func splash(_ context: GraphicsContext, progress: Double) {
        let water = Color(red: 0.62, green: 0.82, blue: 1)
        let fade = 1 - progress
        context.fill(
            Path(ellipse: CGPoint(x: 50, y: 95), rx: 22 + 10 * progress, ry: 3.5),
            with: .color(water.opacity(0.45 * fade)))
        for index in 0..<6 {
            let side: Double = index < 3 ? -1 : 1
            let spread = 12 + Double(index % 3) * 7
            let x = 50 + side * (14 + spread * progress)
            let y = 94 - sin(.pi * progress) * (10 + Double(index % 3) * 5)
            context.fill(Path(ellipse: CGPoint(x: x, y: y), rx: 1.8, ry: 2.2), with: .color(water.opacity(fade)))
        }
    }

    /// Bright paper pieces bursting up over the pet and fluttering down.
    static func confetti(_ context: GraphicsContext, progress: Double) {
        let colours: [Color] = [
            Color(red: 1, green: 0.42, blue: 0.42), Color(red: 1, green: 0.8, blue: 0.3),
            Color(red: 0.4, green: 0.8, blue: 0.5),
            Color(red: 0.4, green: 0.65, blue: 1), Color(red: 0.85, green: 0.5, blue: 1),
        ]
        let fade = progress < 0.75 ? 1 : 1 - (progress - 0.75) / 0.25
        for index in 0..<18 {
            let angle = (Double(index) / 18 - 0.5) * 2.4
            let speed = 34 + Double(index * 7 % 5) * 6
            // Up and out fast, then a slow flutter down.
            let burst = 1 - pow(1 - min(1, progress * 2.5), 2)
            let sinkTime = max(0, progress - 0.3)
            let x = 50 + sin(angle) * speed * burst + sin(progress * 14 + Double(index)) * 3 * sinkTime
            let y = 30 - cos(angle) * speed * 0.8 * burst + sinkTime * 70
            let spin = progress * 900 + Double(index) * 40
            context.fill(
                Path(
                    ellipse: CGPoint(x: x, y: y), rx: 2.4 * abs(cos(spin * .pi / 180)) + 0.4, ry: 1.3,
                    degrees: angle * 30),
                with: .color(colours[index % colours.count].opacity(fade)))
        }
    }
}
