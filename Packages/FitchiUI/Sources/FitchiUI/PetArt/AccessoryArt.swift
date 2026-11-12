import FitchiCore
import SwiftUI

/// Where accessories sit on one species, in the 100×100 art space (before the pose is applied).
struct PetFit: Sendable {
    /// Top centre of the head, and its half-width there.
    var headTop: CGFloat
    var headRadius: CGFloat
    /// Eye line and how far each eye sits from the centre.
    var eyeY: CGFloat
    var eyeSpread: CGFloat
    /// Where the head meets the body, and the half-width there.
    var neckY: CGFloat
    var neckRadius: CGFloat
    /// Centre height and half-width of the body.
    var bodyY: CGFloat
    var bodyRadius: CGFloat

    static let dog = PetFit(
        headTop: 23, headRadius: 28, eyeY: 45, eyeSpread: 11, neckY: 68, neckRadius: 16, bodyY: 77, bodyRadius: 19)

    static let fits: [String: PetFit] = [
        "axolotl": PetFit(
            headTop: 22, headRadius: 33, eyeY: 46, eyeSpread: 14, neckY: 68, neckRadius: 18, bodyY: 76, bodyRadius: 21),
        "golden-axolotl": PetFit(
            headTop: 16, headRadius: 33, eyeY: 46, eyeSpread: 14, neckY: 68, neckRadius: 18, bodyY: 76, bodyRadius: 21),
        "cat": PetFit(
            headTop: 24, headRadius: 29, eyeY: 47, eyeSpread: 12, neckY: 68, neckRadius: 15, bodyY: 77, bodyRadius: 18),
        "dog": dog,
        "bunny": PetFit(
            headTop: 28, headRadius: 26, eyeY: 48, eyeSpread: 11, neckY: 69, neckRadius: 15, bodyY: 78, bodyRadius: 18),
        "red-panda": PetFit(
            headTop: 26, headRadius: 29, eyeY: 47, eyeSpread: 12, neckY: 69, neckRadius: 15, bodyY: 78, bodyRadius: 18),
        "penguin": PetFit(
            headTop: 29, headRadius: 22, eyeY: 49, eyeSpread: 9, neckY: 66, neckRadius: 21, bodyY: 68, bodyRadius: 26),
        "platypus": PetFit(
            headTop: 28, headRadius: 25, eyeY: 44, eyeSpread: 11, neckY: 70, neckRadius: 16, bodyY: 78, bodyRadius: 21),
    ]

    static func fit(for speciesID: String) -> PetFit {
        fits[speciesID] ?? dog
    }
}

/// Wearable accessories, drawn over (or behind) any species using its `PetFit`. Item ids come
/// from `Content/items.json`; ids without a drawing are skipped.
enum AccessoryArt {
    /// Every accessory id that has a drawing.
    static let drawn: Set<String> = [
        "sweatband", "party-hat", "flower-crown", "sunglasses", "red-bandana", "mini-backpack", "hero-cape",
    ]

    /// Parts that hang behind the pet: capes and backpacks.
    static func drawBehind(_ equipped: [AccessorySlot: String], _ ink: Ink, fit: PetFit) {
        switch equipped[.back] {
        case "hero-cape": cape(ink, fit: fit)
        case "mini-backpack": backpack(ink, fit: fit)
        default: break
        }
    }

    /// Parts in front: neck, then face, then head, so a hat sits over sunglasses' arms.
    static func drawInFront(_ equipped: [AccessorySlot: String], _ ink: Ink, fit: PetFit, headBob: Double) {
        switch equipped[.back] {
        case "hero-cape": clasp(ink, fit: fit)
        case "mini-backpack": straps(ink, fit: fit)
        default: break
        }
        if equipped[.neck] == "red-bandana" { bandana(ink, fit: fit) }
        var head = ink
        head.context.translateBy(x: 0, y: headBob)
        if equipped[.face] == "sunglasses" { sunglasses(head, fit: fit) }
        switch equipped[.head] {
        case "sweatband": sweatband(head, fit: fit)
        case "party-hat": partyHat(head, fit: fit)
        case "flower-crown": flowerCrown(head, fit: fit)
        default: break
        }
    }

    private static func tone(_ hex: UInt32) -> Tone { Tone(PetColor(hex: hex)) }

    // MARK: - Head

    private static func sweatband(_ ink: Ink, fit: PetFit) {
        let top = fit.headTop + 5
        let half = fit.headRadius * 0.8
        var band = Path()
        band.move(to: CGPoint(x: 50 - half, y: top + 6))
        band.addQuadCurve(to: CGPoint(x: 50 + half, y: top + 6), control: CGPoint(x: 50, y: top - 5))
        band.addLine(to: CGPoint(x: 50 + half + 0.5, y: top + 12))
        band.addQuadCurve(to: CGPoint(x: 50 - half - 0.5, y: top + 12), control: CGPoint(x: 50, y: top + 1))
        band.closeSubpath()
        ink.part(band, tone(0xFF5A6E))
        var stripe = Path()
        stripe.move(to: CGPoint(x: 50 - half + 1, y: top + 9))
        stripe.addQuadCurve(to: CGPoint(x: 50 + half - 1, y: top + 9), control: CGPoint(x: 50, y: top - 1.5))
        ink.line(stripe, .white, width: 1.6)
    }

    private static func partyHat(_ ink: Ink, fit: PetFit) {
        let base = CGPoint(x: 50, y: fit.headTop + 5)
        let cone = Path(
            roundedPolygon: [
                CGPoint(x: base.x - 10, y: base.y), CGPoint(x: base.x + 2, y: base.y - 24),
                CGPoint(x: base.x + 10, y: base.y),
            ], radius: 1.5)
        ink.part(cone, tone(0x7C8CFF))
        ink.context.drawLayer { layer in
            layer.clip(to: cone)
            for (offset, hex) in [(-6.0, 0xFFD54D), (-14, 0xFF7BAC)] {
                layer.fill(
                    Path(ellipse: CGPoint(x: base.x, y: base.y + offset), rx: 14, ry: 2.4),
                    with: .color(PetColor(hex: UInt32(hex)).color))
            }
        }
        ink.part(Path(ellipse: CGPoint(x: base.x + 2, y: base.y - 25), rx: 3.6, ry: 3.6), tone(0xFFD54D), gloss: true)
    }

    private static func flowerCrown(_ ink: Ink, fit: PetFit) {
        let center = CGPoint(x: 50, y: fit.headTop + 9)
        let colours: [UInt32] = [0xFF9EC0, 0xFFFFFF, 0xFFD54D, 0xFF9EC0, 0xFFFFFF]
        for (index, colour) in colours.enumerated() {
            let angle = (200 + Double(index) * 35) * .pi / 180
            let spot = CGPoint(
                x: center.x + cos(angle) * fit.headRadius * 0.62, y: center.y + sin(angle) * 9 + 2)
            let leaf = Path(ellipse: CGPoint(x: spot.x + 3.5, y: spot.y + 1.5), rx: 3, ry: 1.6, degrees: 30)
            ink.part(leaf, tone(0x5DB36A), shaded: false)
            flower(ink, at: spot, colour: colour)
        }
    }

    private static func flower(_ ink: Ink, at center: CGPoint, colour: UInt32) {
        var petals = Path()
        for petal in 0..<5 {
            let angle = Double(petal) / 5 * 2 * .pi - .pi / 2
            petals.addEllipse(
                in: CGRect(
                    x: center.x + cos(angle) * 2.6 - 2.3, y: center.y + sin(angle) * 2.6 - 2.3, width: 4.6, height: 4.6)
            )
        }
        ink.part(petals, tone(colour), shaded: false)
        ink.part(Path(ellipse: center, rx: 1.6, ry: 1.6), tone(0xFFB33D), shaded: false, outlined: false)
    }

    // MARK: - Face

    private static func sunglasses(_ ink: Ink, fit: PetFit) {
        let lensY = fit.eyeY + 0.5
        // Close-set eyes (the penguin) still get two separate lenses.
        let spread = max(fit.eyeSpread, 10.5)
        let lenses = [CGPoint(x: 50 - spread, y: lensY), CGPoint(x: 50 + spread, y: lensY)]
        var bridge = Path()
        bridge.move(to: CGPoint(x: lenses[0].x + 5, y: lensY - 2))
        bridge.addQuadCurve(to: CGPoint(x: lenses[1].x - 5, y: lensY - 2), control: CGPoint(x: 50, y: lensY - 5))
        ink.line(bridge, PetColor(hex: 0x2A2235).color, width: 1.8)
        for lens in lenses {
            let shape = Path(
                roundedRect: CGRect(x: lens.x - 7.5, y: lens.y - 5.5, width: 15, height: 11), cornerRadius: 4.5)
            ink.part(shape, tone(0x2A2235), shaded: false, gloss: true)
            var glint = Path()
            glint.move(to: CGPoint(x: lens.x - 4, y: lens.y + 1))
            glint.addLine(to: CGPoint(x: lens.x - 1, y: lens.y - 3))
            ink.context.stroke(
                glint, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }

    // MARK: - Neck

    private static func bandana(_ ink: Ink, fit: PetFit) {
        let y = fit.neckY
        let half = fit.neckRadius
        let scarf = Path(
            roundedPolygon: [
                CGPoint(x: 50 - half - 1, y: y - 1), CGPoint(x: 50 + half + 1, y: y - 1), CGPoint(x: 50, y: y + 13),
            ], radius: 3)
        ink.part(scarf, tone(0xE5484D))
        for (offsetX, offsetY) in [(-7.0, 2.5), (6, 2), (0, 7), (-1, 1)] {
            ink.context.fill(
                Path(ellipse: CGPoint(x: 50 + offsetX, y: y + offsetY), rx: 1.1, ry: 1.1),
                with: .color(.white.opacity(0.9)))
        }
        // The knot peeking out at the side.
        ink.part(Path(ellipse: CGPoint(x: 50 + half - 1, y: y - 1), rx: 3, ry: 2.4), tone(0xE5484D), shaded: false)
    }

    // MARK: - Back

    private static func cape(_ ink: Ink, fit: PetFit) {
        let top = fit.neckY - 2
        let spread = fit.bodyRadius + 9
        var cloak = Path()
        cloak.move(to: CGPoint(x: 50 - fit.neckRadius, y: top))
        cloak.addLine(to: CGPoint(x: 50 + fit.neckRadius, y: top))
        cloak.addQuadCurve(to: CGPoint(x: 50 + spread, y: Ink.ground - 3), control: CGPoint(x: 50 + spread, y: top + 6))
        cloak.addQuadCurve(to: CGPoint(x: 50 - spread, y: Ink.ground - 3), control: CGPoint(x: 50, y: Ink.ground + 3))
        cloak.addQuadCurve(to: CGPoint(x: 50 - fit.neckRadius, y: top), control: CGPoint(x: 50 - spread, y: top + 6))
        cloak.closeSubpath()
        ink.part(cloak, tone(0xD7364A))
    }

    private static func clasp(_ ink: Ink, fit: PetFit) {
        for side in [-1.0, 1] {
            let collar = Path(
                roundedPolygon: [
                    CGPoint(x: 50 + side * 2, y: fit.neckY - 1),
                    CGPoint(x: 50 + side * (fit.neckRadius + 2), y: fit.neckY - 3),
                    CGPoint(x: 50 + side * (fit.neckRadius - 3), y: fit.neckY + 4),
                ], radius: 1.5)
            ink.part(collar, tone(0xD7364A), shaded: false)
        }
        ink.part(Path(ellipse: CGPoint(x: 50, y: fit.neckY), rx: 3, ry: 3), tone(0xFFD54D), shaded: false, gloss: true)
    }

    private static func backpack(_ ink: Ink, fit: PetFit) {
        let width = fit.bodyRadius * 2 + 16
        let pack = Path(
            roundedRect: CGRect(x: 50 - width / 2, y: fit.bodyY - 20, width: width, height: 24), cornerRadius: 9)
        ink.part(pack, tone(0xFF9F43))
        // Side pockets peeking out.
        for side in [-1.0, 1] {
            ink.part(
                Path(
                    roundedRect: CGRect(x: 50 + side * (width / 2 + 1) - 3.5, y: fit.bodyY - 9, width: 7, height: 11),
                    cornerRadius: 2.5),
                tone(0xF07F2B), shaded: false)
        }
    }

    private static func straps(_ ink: Ink, fit: PetFit) {
        for side in [-1.0, 1] {
            var strap = Path()
            strap.move(to: CGPoint(x: 50 + side * fit.neckRadius * 0.75, y: fit.neckY - 1))
            strap.addQuadCurve(
                to: CGPoint(x: 50 + side * fit.bodyRadius * 0.8, y: fit.bodyY + 5),
                control: CGPoint(x: 50 + side * fit.bodyRadius * 0.95, y: fit.bodyY - 6))
            ink.line(strap, PetColor(hex: 0xC9651F).color, width: 3)
        }
    }
}
