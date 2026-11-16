import SwiftUI

/// The second wave of the wardrobe: hats, glasses, neckwear and wings. Like the first, each is
/// placed from the species' `PetFit`, so it fits every pet without per-species drawings.
extension AccessoryArt {
    static let wardrobe: Set<String> = [
        "cozy-beanie", "royal-crown", "pink-bow", "heart-glasses", "round-specs", "cozy-scarf", "bow-tie",
        "bell-collar", "fairy-wings",
    ]

    static func drawWardrobeBehind(_ id: String?, _ ink: Ink, fit: PetFit) {
        if id == "fairy-wings" { fairyWings(ink, fit: fit) }
    }

    static func drawWardrobeNeck(_ id: String?, _ ink: Ink, fit: PetFit) {
        switch id {
        case "cozy-scarf": cozyScarf(ink, fit: fit)
        case "bow-tie": bowTie(ink, fit: fit)
        case "bell-collar": bellCollar(ink, fit: fit)
        default: break
        }
    }

    static func drawWardrobeFace(_ id: String?, _ ink: Ink, fit: PetFit) {
        switch id {
        case "heart-glasses": heartGlasses(ink, fit: fit)
        case "round-specs": roundSpecs(ink, fit: fit)
        default: break
        }
    }

    static func drawWardrobeHead(_ id: String?, _ ink: Ink, fit: PetFit) {
        switch id {
        case "cozy-beanie": beanie(ink, fit: fit)
        case "royal-crown": crown(ink, fit: fit)
        case "pink-bow": bow(ink, fit: fit)
        default: break
        }
    }

    private static func shade(_ hex: UInt32) -> Tone { Tone(PetColor(hex: hex)) }

    // MARK: - Head

    private static func beanie(_ ink: Ink, fit: PetFit) {
        let top = fit.headTop
        let half = fit.headRadius * 0.82
        var dome = Path()
        dome.move(to: CGPoint(x: 50 - half, y: top + 9))
        dome.addCurve(
            to: CGPoint(x: 50 + half, y: top + 9), control1: CGPoint(x: 50 - half, y: top - 13),
            control2: CGPoint(x: 50 + half, y: top - 13))
        dome.closeSubpath()
        ink.part(dome, shade(0x4FA3E0))
        // Knit ribs.
        for rib in stride(from: -0.6, through: 0.6, by: 0.3) {
            var line = Path()
            line.move(to: CGPoint(x: 50 + half * rib, y: top + 6))
            line.addQuadCurve(
                to: CGPoint(x: 50 + half * rib * 0.5, y: top - 5), control: CGPoint(x: 50 + half * rib * 0.95, y: top))
            ink.context.stroke(
                line, with: .color(.white.opacity(0.25)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
        let cuff = Path(
            roundedRect: CGRect(x: 50 - half - 1.5, y: top + 5, width: half * 2 + 3, height: 7), cornerRadius: 3.5)
        ink.part(cuff, shade(0xF4F1EA))
        ink.part(Path(ellipse: CGPoint(x: 50, y: top - 7), rx: 4.6, ry: 4.4), shade(0xF4F1EA))
    }

    private static func crown(_ ink: Ink, fit: PetFit) {
        let base = fit.headTop + 5
        let half = min(12, fit.headRadius * 0.45)
        let points = [
            CGPoint(x: 50 - half, y: base), CGPoint(x: 50 - half - 1.5, y: base - 13),
            CGPoint(x: 50 - half * 0.5, y: base - 7), CGPoint(x: 50, y: base - 16),
            CGPoint(x: 50 + half * 0.5, y: base - 7), CGPoint(x: 50 + half + 1.5, y: base - 13),
            CGPoint(x: 50 + half, y: base),
        ]
        ink.part(Path(roundedPolygon: points, radius: 1.2), shade(0xFFC93D), gloss: true)
        for (x, hex) in [(-half * 0.55, 0xE5484D), (0, 0x4FA3E0), (half * 0.55, 0x5DB36A)] {
            ink.part(
                Path(ellipse: CGPoint(x: 50 + x, y: base - 3.5), rx: 1.8, ry: 1.8), shade(UInt32(hex)), shaded: false)
        }
        for tip in [points[1], points[3], points[5]] {
            ink.part(Path(ellipse: tip, rx: 1.7, ry: 1.7), shade(0xFFE89A), shaded: false)
        }
    }

    private static func bow(_ ink: Ink, fit: PetFit) {
        let knot = CGPoint(x: 50 + fit.headRadius * 0.5, y: fit.headTop + 5)
        for side in [-1.0, 1] {
            let loop = Path(
                roundedPolygon: [
                    knot, CGPoint(x: knot.x + side * 9, y: knot.y - 6), CGPoint(x: knot.x + side * 9, y: knot.y + 5),
                ], radius: 2.5)
            ink.part(loop, shade(0xFF7BAC))
        }
        ink.part(Path(ellipse: knot, rx: 2.8, ry: 3), shade(0xF25A93), shaded: false)
    }

    // MARK: - Face

    private static func heartGlasses(_ ink: Ink, fit: PetFit) {
        let y = fit.eyeY + 0.5
        let spread = max(fit.eyeSpread, 10.5)
        var bridge = Path()
        bridge.move(to: CGPoint(x: 50 - spread + 5, y: y - 2))
        bridge.addQuadCurve(to: CGPoint(x: 50 + spread - 5, y: y - 2), control: CGPoint(x: 50, y: y - 5))
        ink.line(bridge, PetColor(hex: 0xC2185B).color, width: 1.6)
        for x in [50 - spread, 50 + spread] {
            ink.part(heart(at: CGPoint(x: x, y: y), size: 7.5), shade(0xFF5C9A), shaded: false, gloss: true)
        }
    }

    /// A heart centred on `center`, about `size` across each lobe.
    private static func heart(at center: CGPoint, size: CGFloat) -> Path {
        var path = Path()
        let top = center.y - size * 0.35
        path.move(to: CGPoint(x: center.x, y: center.y + size * 0.85))
        path.addCurve(
            to: CGPoint(x: center.x - size, y: top),
            control1: CGPoint(x: center.x - size * 0.4, y: center.y + size * 0.45),
            control2: CGPoint(x: center.x - size, y: center.y + size * 0.15))
        path.addArc(
            center: CGPoint(x: center.x - size * 0.5, y: top), radius: size * 0.5, startAngle: .degrees(180),
            endAngle: .degrees(0), clockwise: false)
        path.addArc(
            center: CGPoint(x: center.x + size * 0.5, y: top), radius: size * 0.5, startAngle: .degrees(180),
            endAngle: .degrees(0), clockwise: false)
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y + size * 0.85),
            control1: CGPoint(x: center.x + size, y: center.y + size * 0.15),
            control2: CGPoint(x: center.x + size * 0.4, y: center.y + size * 0.45))
        path.closeSubpath()
        return path
    }

    private static func roundSpecs(_ ink: Ink, fit: PetFit) {
        let y = fit.eyeY + 0.5
        let spread = max(fit.eyeSpread, 10.5)
        let frame = PetColor(hex: 0x6B4A2E).color
        var bridge = Path()
        bridge.move(to: CGPoint(x: 50 - spread + 6.5, y: y - 1))
        bridge.addQuadCurve(to: CGPoint(x: 50 + spread - 6.5, y: y - 1), control: CGPoint(x: 50, y: y - 4))
        ink.line(bridge, frame, width: 1.4)
        for x in [50 - spread, 50 + spread] {
            let lens = Path(ellipse: CGPoint(x: x, y: y), rx: 6.5, ry: 6.5)
            ink.context.fill(lens, with: .color(.white.opacity(0.22)))
            ink.line(lens, frame, width: 1.6)
            var glint = Path()
            glint.addArc(
                center: CGPoint(x: x, y: y), radius: 4.3, startAngle: .degrees(200), endAngle: .degrees(250),
                clockwise: false)
            ink.context.stroke(
                glint, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
    }

    // MARK: - Neck

    private static func cozyScarf(_ ink: Ink, fit: PetFit) {
        let y = fit.neckY
        let half = fit.neckRadius + 2
        // The tail hangs down one side, under the wrap.
        let tail = Path(
            roundedRect: CGRect(x: 50 + half * 0.35, y: y + 1, width: 7, height: 15), cornerRadius: 2.5)
        ink.part(tail, shade(0xE5484D))
        for stripe in [y + 6, y + 11] {
            ink.context.fill(
                Path(CGRect(x: 50 + half * 0.35 + 0.8, y: stripe, width: 5.4, height: 2)),
                with: .color(PetColor(hex: 0xF4F1EA).color))
        }
        let wrap = Path(roundedRect: CGRect(x: 50 - half, y: y - 4, width: half * 2, height: 8), cornerRadius: 4)
        ink.part(wrap, shade(0xE5484D))
        for offset in stride(from: -half + 5, to: half - 2, by: 6) {
            ink.context.fill(
                Path(roundedRect: CGRect(x: 50 + offset, y: y - 4, width: 2.2, height: 8), cornerRadius: 1),
                with: .color(PetColor(hex: 0xF4F1EA).color.opacity(0.9)))
        }
    }

    private static func bowTie(_ ink: Ink, fit: PetFit) {
        let knot = CGPoint(x: 50, y: fit.neckY + 1)
        for side in [-1.0, 1] {
            let wing = Path(
                roundedPolygon: [
                    knot, CGPoint(x: knot.x + side * 8, y: knot.y - 4.5),
                    CGPoint(x: knot.x + side * 8, y: knot.y + 4.5),
                ], radius: 1.8)
            ink.part(wing, shade(0x3B3F8F))
        }
        ink.part(Path(ellipse: knot, rx: 2.4, ry: 2.6), shade(0x2C2F70), shaded: false)
        for side in [-1.0, 1] {
            ink.context.fill(
                Path(ellipse: CGPoint(x: knot.x + side * 5, y: knot.y), rx: 0.9, ry: 0.9),
                with: .color(.white.opacity(0.85)))
        }
    }

    private static func bellCollar(_ ink: Ink, fit: PetFit) {
        let y = fit.neckY
        let half = fit.neckRadius + 0.5
        var band = Path()
        band.move(to: CGPoint(x: 50 - half, y: y - 2))
        band.addQuadCurve(to: CGPoint(x: 50 + half, y: y - 2), control: CGPoint(x: 50, y: y + 3))
        ink.line(band, PetColor(hex: 0x2A2235).color, width: 4.2)
        ink.line(band, PetColor(hex: 0x4FBF8F).color, width: 2.6)
        let bell = CGPoint(x: 50, y: y + 4)
        ink.part(Path(ellipse: bell, rx: 3.6, ry: 3.4), shade(0xFFC93D), gloss: true)
        var slit = Path()
        slit.move(to: CGPoint(x: bell.x - 2, y: bell.y + 1.2))
        slit.addLine(to: CGPoint(x: bell.x + 2, y: bell.y + 1.2))
        ink.line(slit, PetColor(hex: 0x8A5A00).color, width: 0.9)
    }

    // MARK: - Back

    private static func fairyWings(_ ink: Ink, fit: PetFit) {
        // Rooted between the shoulders and fanning up and out, so they show past any body.
        let root = CGPoint(x: 50, y: fit.neckY + 4)
        let reach = fit.bodyRadius + 17
        for side in [-1.0, 1] {
            let upper = Path(
                ellipse: CGPoint(x: root.x + side * reach * 0.6, y: root.y - 12), rx: reach * 0.52, ry: 9,
                degrees: side * -32)
            let lower = Path(
                ellipse: CGPoint(x: root.x + side * reach * 0.55, y: root.y + 3), rx: reach * 0.36, ry: 6,
                degrees: side * 22)
            for wing in [lower, upper] {
                ink.part(wing, shade(0xC9B8FF), shaded: false)
                ink.context.fill(wing, with: .color(.white.opacity(0.3)))
            }
            // A vein down the middle of the big wing, and a sparkle at its tip.
            var vein = Path()
            vein.move(to: CGPoint(x: root.x + side * 4, y: root.y - 4))
            vein.addQuadCurve(
                to: CGPoint(x: root.x + side * reach * 0.95, y: root.y - 20),
                control: CGPoint(x: root.x + side * reach * 0.45, y: root.y - 8))
            ink.context.stroke(
                vein, with: .color(.white.opacity(0.8)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            ink.context.fill(
                Path(ellipse: CGPoint(x: root.x + side * reach * 0.9, y: root.y - 21), rx: 1.5, ry: 1.5),
                with: .color(.white))
        }
    }
}
