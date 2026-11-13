import FitchiCore
import SwiftUI

/// A small ring showing one stat, for the corners of the pet screen.
public struct StatRing: View {
    private let stat: Stat
    private let value: Double

    public init(_ stat: Stat, value: Double) {
        self.stat = stat
        self.value = value
    }

    public var body: some View {
        ZStack {
            Circle().stroke(stat.color.opacity(0.25), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(0.02, min(value / 100, 1)))
                .stroke(stat.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: stat.systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(stat.color)
        }
        .frame(width: 24, height: 24)
        .animation(.spring(duration: 0.6), value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.title): \(Int(value.rounded())) out of 100")
    }
}

/// A thin labelled bar, for the Horizon layout.
public struct StatPip: View {
    private let stat: Stat
    private let value: Double

    public init(_ stat: Stat, value: Double) {
        self.stat = stat
        self.value = value
    }

    public var body: some View {
        VStack(spacing: 2) {
            Capsule()
                .fill(stat.color.opacity(0.25))
                .overlay(alignment: .leading) {
                    GeometryReader { geometry in
                        Capsule().fill(stat.color).frame(width: geometry.size.width * max(0.04, min(value / 100, 1)))
                    }
                }
                .frame(height: 5)
            Image(systemName: stat.systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(stat.color)
        }
        .animation(.spring(duration: 0.6), value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stat.title): \(Int(value.rounded())) out of 100")
    }
}

/// Rises and fades out once.
struct FloatingReward: View {
    let text: String
    @State private var risen = false

    var body: some View {
        Text(text)
            .font(FitchiTheme.Fonts.display(.headline, weight: .heavy).monospacedDigit())
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 2)
            .offset(y: risen ? -30 : 0)
            .opacity(risen ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.4)) { risen = true }
            }
            .accessibilityHidden(true)
    }
}

/// A footprint or dust puff placed on the stage: where the foot landed and how big the pet is
/// at that depth.
struct GroundMark {
    var step: Footstep
    var point: CGPoint
    var petSize: CGFloat
}

/// Footprints in snow and sand that fade, or puffs of dust kicked up on grass.
struct GroundMarks: View {
    let marks: [GroundMark]
    let footing: Footing

    var body: some View {
        Canvas { context, _ in
            for mark in marks {
                let fade = max(0, 1 - mark.step.age / footing.lasting)
                let point = CGPoint(x: mark.point.x + mark.step.foot * mark.petSize * 0.1, y: mark.point.y)
                switch footing {
                case .prints(let color):
                    // Fresh prints are crisp; they soften away as the ground settles.
                    let width = mark.petSize * 0.07
                    context.fill(
                        Path(ellipse: point, rx: width, ry: width * 0.42),
                        with: .color(color.opacity(0.55 * min(1, fade * 1.6))))
                case .puffs(let color):
                    let spread = mark.step.age / footing.lasting
                    for side in [-1.0, 1.0] {
                        let radius = mark.petSize * (0.03 + 0.05 * spread)
                        let center = CGPoint(
                            x: point.x + side * mark.petSize * 0.07 * spread,
                            y: point.y - mark.petSize * 0.04 * spread)
                        context.fill(
                            Path(ellipse: center, rx: radius, ry: radius * 0.8),
                            with: .color(color.opacity(0.6 * fade)))
                    }
                case .none: break
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
