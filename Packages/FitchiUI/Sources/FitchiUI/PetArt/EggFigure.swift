import SwiftUI

/// The mystery egg, drawn in the same style as the pets. `crack` (0…1) grows a zigzag crack
/// across its middle as it gets ready to hatch.
public struct EggFigure: View {
    private let crack: Double

    public init(crack: Double = 0) {
        self.crack = crack
    }

    public var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 100
            context.translateBy(x: (size.width - 100 * scale) / 2, y: (size.height - 100 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            context.fill(Path(ellipse: CGPoint(x: 50, y: 93), rx: 22, ry: 4), with: .color(.black.opacity(0.18)))
            let ink = Ink(context: context)
            let shell = Self.shell
            ink.part(shell, Tone(PetColor(hex: 0xFFF4DC)), gloss: true)
            context.drawLayer { layer in
                layer.clip(to: shell)
                for spot in Self.spots {
                    layer.fill(
                        Path(
                            ellipse: CGPoint(x: spot.x, y: spot.y), rx: spot.radius, ry: spot.radius * 0.8, degrees: 15),
                        with: .color(PetColor(hex: spot.hex).color))
                }
            }
            if crack > 0 {
                ink.line(Self.crackPath(progress: crack), PetColor.lineInk.color, width: 2)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    static let shell: Path = {
        var path = Path()
        path.move(to: CGPoint(x: 50, y: 12))
        path.addCurve(to: CGPoint(x: 78, y: 62), control1: CGPoint(x: 67, y: 12), control2: CGPoint(x: 78, y: 40))
        path.addCurve(to: CGPoint(x: 50, y: 93), control1: CGPoint(x: 78, y: 82), control2: CGPoint(x: 66, y: 93))
        path.addCurve(to: CGPoint(x: 22, y: 62), control1: CGPoint(x: 34, y: 93), control2: CGPoint(x: 22, y: 82))
        path.addCurve(to: CGPoint(x: 50, y: 12), control1: CGPoint(x: 22, y: 40), control2: CGPoint(x: 33, y: 12))
        path.closeSubpath()
        return path
    }()

    struct Spot {
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
        let hex: UInt32
    }

    static let spots = [
        Spot(x: 38, y: 30, radius: 6, hex: 0x9FE3D8), Spot(x: 62, y: 42, radius: 7.5, hex: 0xFFB7CF),
        Spot(x: 34, y: 68, radius: 8, hex: 0xC9B6FF), Spot(x: 64, y: 76, radius: 5.5, hex: 0x9FE3D8),
        Spot(x: 52, y: 22, radius: 3.5, hex: 0xFFD27A), Spot(x: 48, y: 84, radius: 3.5, hex: 0xFFB7CF),
    ]

    /// A zigzag across the egg that grows from the left as `progress` goes 0 → 1.
    static func crackPath(progress: Double) -> Path {
        let points = [
            CGPoint(x: 23, y: 54), CGPoint(x: 30, y: 49), CGPoint(x: 36, y: 56), CGPoint(x: 43, y: 48),
            CGPoint(x: 50, y: 56), CGPoint(x: 57, y: 48), CGPoint(x: 64, y: 56), CGPoint(x: 70, y: 49),
            CGPoint(x: 77, y: 54),
        ]
        let reach = min(max(progress, 0), 1) * Double(points.count - 1)
        var path = Path()
        path.move(to: points[0])
        for index in 1..<points.count {
            let amount = reach - Double(index - 1)
            guard amount > 0 else { break }
            let from = points[index - 1]
            let target = points[index]
            let step = min(amount, 1)
            path.addLine(to: CGPoint(x: from.x + (target.x - from.x) * step, y: from.y + (target.y - from.y) * step))
        }
        return path
    }
}

/// Sparkles bursting outwards: the shiny reveal.
public struct ShinyBurst: View {
    @State private var burst = false

    public init() {}

    public var body: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                let angle = Double(index) / 10 * 2 * .pi
                let distance: CGFloat = index.isMultiple(of: 2) ? 70 : 52
                SparkleShape()
                    .fill(index.isMultiple(of: 3) ? Color.white : Color(red: 1, green: 0.88, blue: 0.4))
                    .frame(width: index.isMultiple(of: 2) ? 16 : 10, height: index.isMultiple(of: 2) ? 16 : 10)
                    .offset(x: burst ? cos(angle) * distance : 0, y: burst ? sin(angle) * distance : 0)
                    .scaleEffect(burst ? 1 : 0.2)
                    .opacity(burst ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.3)) { burst = true }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A four-point twinkle.
public struct SparkleShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        Sparkles.star(at: CGPoint(x: rect.midX, y: rect.midY), size: min(rect.width, rect.height) / 2)
    }
}
