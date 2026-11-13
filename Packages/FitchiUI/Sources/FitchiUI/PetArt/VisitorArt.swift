import SwiftUI

/// A visitor drawn in a 20×20 art space centred on it.
public struct VisitorView: View {
    private let kind: Visitor.Kind
    private let visitor: Visitor

    public init(kind: Visitor.Kind, visitor: Visitor) {
        self.kind = kind
        self.visitor = visitor
    }

    public var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 20, y: size.height / 20)
            if !visitor.facingRight {
                context.translateBy(x: 20, y: 0)
                context.scaleBy(x: -1, y: 1)
            }
            switch kind {
            case .butterfly: VisitorArt.butterfly(context, visitor: visitor)
            case .bird: VisitorArt.bird(context, visitor: visitor)
            case .firefly: VisitorArt.firefly(context, visitor: visitor)
            }
        }
        .accessibilityHidden(true)
    }
}

enum VisitorArt {
    private static func color(_ hex: UInt32) -> Color { PetColor(hex: hex).color }
    private static let ink = color(0x2A1A33)

    static func butterfly(_ context: GraphicsContext, visitor: Visitor) {
        let wings: [(UInt32, UInt32)] = [(0xFF9EC7, 0xFFD6E8), (0xFFC94D, 0xFFF0B8), (0x8EC9FF, 0xD6EDFF)]
        let (main, light) = wings[visitor.variety % wings.count]
        // Wings open and close; seen edge-on they get thin.
        let open = 0.25 + 0.75 * abs(cos(visitor.clock * 13))
        for side in [-1.0, 1.0] {
            let upper = Path(
                ellipse: CGPoint(x: 10 + side * 4 * open, y: 8.4), rx: 4 * open + 0.4, ry: 3.6, degrees: side * 20)
            let lower = Path(
                ellipse: CGPoint(x: 10 + side * 3 * open, y: 12.2), rx: 2.8 * open + 0.4, ry: 2.4, degrees: -side * 20)
            for wing in [upper, lower] {
                context.fill(wing, with: .color(color(main)))
                context.stroke(wing, with: .color(ink.opacity(0.8)), lineWidth: 0.7)
            }
            context.fill(
                Path(ellipse: CGPoint(x: 10 + side * 4 * open, y: 8), rx: 1.4 * open + 0.2, ry: 1.2),
                with: .color(color(light)))
        }
        context.fill(
            Path(roundedRect: CGRect(x: 9.3, y: 6.5, width: 1.4, height: 8), cornerRadius: 0.7), with: .color(ink))
        var antennae = Path()
        antennae.move(to: CGPoint(x: 9.8, y: 6.8))
        antennae.addQuadCurve(to: CGPoint(x: 8, y: 3.6), control: CGPoint(x: 9, y: 4.5))
        antennae.move(to: CGPoint(x: 10.2, y: 6.8))
        antennae.addQuadCurve(to: CGPoint(x: 12, y: 3.6), control: CGPoint(x: 11, y: 4.5))
        context.stroke(antennae, with: .color(ink), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
    }

    /// A round little bird, drawn facing right.
    static func bird(_ context: GraphicsContext, visitor: Visitor) {
        let colors: [(UInt32, UInt32)] = [(0x6FA8DC, 0xD9ECFA), (0xE8604C, 0xFFE0D6), (0x8C6B4F, 0xF2E3D0)]
        let (body, belly) = colors[visitor.variety % colors.count]
        let shape = Path(ellipse: CGPoint(x: 9.8, y: 11), rx: 5.2, ry: 4.8)
        // A tail cocked up behind, like a wren's.
        var tail = Path()
        tail.move(to: CGPoint(x: 5.2, y: 9.4))
        tail.addLine(to: CGPoint(x: 2.2, y: 4.6))
        tail.addLine(to: CGPoint(x: 4.2, y: 4.2))
        tail.addLine(to: CGPoint(x: 6.6, y: 8.6))
        tail.closeSubpath()
        context.fill(tail, with: .color(color(body)))
        context.stroke(tail, with: .color(ink), lineWidth: 0.7)
        context.fill(shape, with: .color(color(body)))
        context.fill(Path(ellipse: CGPoint(x: 10.5, y: 12.6), rx: 3.6, ry: 2.6), with: .color(color(belly)))
        context.stroke(shape, with: .color(ink), lineWidth: 0.8)
        var beak = Path()
        beak.move(to: CGPoint(x: 14.6, y: 9.4))
        beak.addLine(to: CGPoint(x: 17.4, y: 10.4))
        beak.addLine(to: CGPoint(x: 14.6, y: 11.2))
        beak.closeSubpath()
        context.fill(beak, with: .color(color(0xFFB347)))
        context.fill(Path(ellipse: CGPoint(x: 12.6, y: 9.2), rx: 0.8, ry: 0.8), with: .color(ink))
        // The wing beats up and down.
        let beat = sin(visitor.clock * 16)
        let wing = Path(ellipse: CGPoint(x: 8.6, y: 9.6 - beat * 1.4), rx: 3.4, ry: 1.8, degrees: -15 - beat * 30)
        context.fill(wing, with: .color(color(body)))
        context.stroke(wing, with: .color(ink), lineWidth: 0.7)
    }

    static func firefly(_ context: GraphicsContext, visitor: Visitor) {
        let glow = Color(red: 1, green: 0.95, blue: 0.48)
        let pulse = 0.55 + 0.45 * sin(visitor.clock * 3)
        let center = CGPoint(x: 10, y: 10)
        context.fill(
            Path(ellipse: center, rx: 9, ry: 9),
            with: .radialGradient(
                Gradient(colors: [glow.opacity(0.6 * pulse), .clear]), center: center, startRadius: 0, endRadius: 9))
        context.fill(Path(ellipse: center, rx: 1.8, ry: 1.8), with: .color(glow))
        context.fill(Path(ellipse: CGPoint(x: 8.4, y: 9), rx: 1.4, ry: 1), with: .color(ink.opacity(0.7)))
    }
}
