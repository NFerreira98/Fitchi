import SwiftUI

/// A few things with a story behind them: a knitted star sweater, a yellow raincoat for puddle
/// days, a dragonfly hair clip and a small red bow worn over one ear.
extension AccessoryArt {
    static let nods: Set<String> = ["star-sweater", "yellow-raincoat", "dragonfly-clip", "red-bow"]

    static func drawNodsBehind(_ id: String?, _ ink: Ink, fit: PetFit) {
        if id == "yellow-raincoat" { hood(ink, fit: fit) }
    }

    /// Worn on the body, over the fur but under the neck things.
    static func drawNodsFront(_ id: String?, _ ink: Ink, fit: PetFit) {
        switch id {
        case "star-sweater": sweater(ink, fit: fit)
        case "yellow-raincoat": raincoat(ink, fit: fit)
        default: break
        }
    }

    static func drawNodsHead(_ id: String?, _ ink: Ink, fit: PetFit) {
        switch id {
        case "dragonfly-clip": dragonfly(ink, fit: fit)
        case "red-bow": redBow(ink, fit: fit)
        default: break
        }
    }

    private static func shade(_ hex: UInt32) -> Tone { Tone(PetColor(hex: hex)) }

    /// The torso of a garment: from under the chin to just above the paws.
    private static func torso(_ fit: PetFit) -> Path {
        let top = fit.neckY + 1
        let bottom = fit.bodyY + fit.bodyRadius * 0.55
        let half = fit.bodyRadius + 2.5
        return Path(roundedRect: CGRect(x: 50 - half, y: top, width: half * 2, height: bottom - top), cornerRadius: 7)
    }

    // MARK: - Body

    private static func sweater(_ ink: Ink, fit: PetFit) {
        let body = torso(fit)
        ink.part(body, shade(0x3F6FD8), gloss: false)
        let hem = body.boundingRect
        ink.part(
            Path(roundedRect: CGRect(x: hem.minX, y: hem.maxY - 3.2, width: hem.width, height: 3.2), cornerRadius: 1.4),
            shade(0x3560C2), shaded: false)
        for x in stride(from: hem.minX + 2, to: hem.maxX - 1, by: 2.2) {
            ink.context.fill(
                Path(CGRect(x: x, y: hem.maxY - 2.8, width: 0.6, height: 2.4)), with: .color(.white.opacity(0.18)))
        }
        for (shiftX, shiftY, size) in [(-7.0, 3.0, 2.4), (5, 2, 2), (-1, 7.5, 1.8), (8, 8, 1.6), (-8, 10, 1.4)] {
            let point = CGPoint(x: hem.midX + shiftX, y: hem.minY + shiftY)
            guard point.y < hem.maxY - 4 else { continue }
            ink.context.fill(Sparkles.star(at: point, size: size), with: .color(PetColor(hex: 0xFFD54D).color))
        }
    }

    private static func raincoat(_ ink: Ink, fit: PetFit) {
        let body = torso(fit)
        ink.part(body, shade(0xFFD23F), gloss: true)
        let box = body.boundingRect
        var placket = Path()
        placket.move(to: CGPoint(x: 50, y: box.minY + 1))
        placket.addLine(to: CGPoint(x: 50, y: box.maxY - 1))
        ink.line(placket, PetColor(hex: 0xE0B020).color, width: 1)
        for y in [box.minY + 4, box.minY + 9] where y < box.maxY - 3 {
            ink.context.fill(
                Path(ellipse: CGPoint(x: 50, y: y), rx: 1.1, ry: 1.1), with: .color(PetColor(hex: 0x2A1A33).color))
        }
        for side in [-1.0, 1] {
            ink.context.stroke(
                Path(
                    roundedRect: CGRect(
                        x: 50 + side * (box.width * 0.28) - 2.5, y: box.maxY - 8, width: 5, height: 3.6),
                    cornerRadius: 0.8),
                with: .color(PetColor(hex: 0xE0B020).color), lineWidth: 0.8)
        }
    }

    /// The raincoat's hood, down on its back.
    private static func hood(_ ink: Ink, fit: PetFit) {
        ink.part(
            Path(ellipse: CGPoint(x: 50, y: fit.neckY - 3), rx: fit.neckRadius + 5, ry: 5.5), shade(0xF2C230),
            shaded: false)
    }

    // MARK: - Head

    private static func dragonfly(_ ink: Ink, fit: PetFit) {
        let spot = CGPoint(x: 50 + fit.headRadius * 0.6, y: fit.headTop + 9)
        let wing = Tone(PetColor(hex: 0xBFE9F5))
        for (shiftX, shiftY, turn) in [(-3.0, -2.5, -35.0), (3, -2.5, 35), (-3.2, 1.5, -15), (3.2, 1.5, 15)] {
            ink.part(
                Path(ellipse: CGPoint(x: spot.x + shiftX, y: spot.y + shiftY), rx: 3.4, ry: 1.3, degrees: turn), wing,
                shaded: false, gloss: true)
        }
        var body = Path()
        body.move(to: CGPoint(x: spot.x, y: spot.y - 3.5))
        body.addLine(to: CGPoint(x: spot.x, y: spot.y + 4.5))
        ink.line(body, PetColor(hex: 0x2EC4B6).color, width: 1.6)
        ink.context.fill(
            Path(ellipse: CGPoint(x: spot.x, y: spot.y - 4), rx: 1.3, ry: 1.3),
            with: .color(PetColor(hex: 0x1FA396).color))
    }

    private static func redBow(_ ink: Ink, fit: PetFit) {
        let knot = CGPoint(x: 50 + fit.headRadius * 0.52, y: fit.headTop + 4)
        for side in [-1.0, 1] {
            let loop = Path(
                roundedPolygon: [
                    knot, CGPoint(x: knot.x + side * 10, y: knot.y - 7), CGPoint(x: knot.x + side * 10, y: knot.y + 6),
                ], radius: 2.8)
            ink.part(loop, shade(0xE5243B), gloss: true)
        }
        ink.part(Path(ellipse: knot, rx: 3, ry: 3.2), shade(0xC41B30), shaded: false)
    }
}
