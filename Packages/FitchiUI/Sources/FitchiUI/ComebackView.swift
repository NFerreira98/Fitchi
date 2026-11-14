import FitchiCore
import SwiftUI

/// The pet's screen while it has run away: its scene, empty but for the pet far off on the
/// horizon, walking a little closer with every active minute (or hundred steps) the player
/// logs, then waiting at the front to be welcomed home. Shared by the watch and the iPhone.
public struct ComebackView: View {
    private let pet: Pet
    private let species: Species?
    private let backdrop: SceneBackdrop.Kind
    private let progress: ComebackProgress
    private let compact: Bool
    private let onWelcome: () -> Void

    /// - Parameters:
    ///   - compact: the watch layout (everything over the scene) rather than the phone's card.
    ///   - onWelcome: called when the player taps "Welcome home" (only offered once complete).
    public init(
        pet: Pet, species: Species?, backdrop: SceneBackdrop.Kind, progress: ComebackProgress, compact: Bool,
        onWelcome: @escaping () -> Void
    ) {
        self.pet = pet
        self.species = species
        self.backdrop = backdrop
        self.progress = progress
        self.compact = compact
        self.onWelcome = onWelcome
    }

    public var body: some View {
        if compact { watchLayout } else { phoneLayout }
    }

    // MARK: - Layouts

    private var watchLayout: some View {
        ZStack {
            ComebackScene(pet: pet, species: species, backdrop: backdrop, fraction: shownFraction, frontScale: 0.42)
                .ignoresSafeArea()
            VStack(spacing: 2) {
                Text(title)
                    .font(FitchiTheme.Fonts.display(.headline))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(progress.isComplete ? "Back from the long walk" : "\(progress.minutesRemaining) active min to go")
                    .font(FitchiTheme.Fonts.text(.caption2, weight: .medium))
                    .opacity(0.85)
                Spacer(minLength: 0)
                if progress.isComplete {
                    welcomeButton
                } else {
                    meter.padding(.horizontal, 18).padding(.bottom, 8)
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.6), radius: 2)
            .padding(.top, 26)
            .ignoresSafeArea(edges: .top)
        }
    }

    private var phoneLayout: some View {
        VStack(alignment: .leading, spacing: FitchiTheme.Spacing.m) {
            ComebackScene(pet: pet, species: species, backdrop: backdrop, fraction: shownFraction, frontScale: 0.32)
                .aspectRatio(1.1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 28))
            Text(title).font(FitchiTheme.Fonts.display(.title))
            Text(explanation)
                .font(FitchiTheme.Fonts.text(.subheadline))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if progress.isComplete {
                welcomeButton.frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    meter
                    HStack {
                        Text("\(Int(progress.activeMinutes.rounded(.down))) of \(Int(progress.requiredMinutes)) min")
                        Spacer()
                        Text("Left \(progress.leftAt.formatted(.relative(presentation: .named)))")
                            .foregroundStyle(.secondary)
                    }
                    .font(FitchiTheme.Fonts.display(.footnote).monospacedDigit())
                }
                .padding(12)
                .background(.fill.tertiary, in: .rect(cornerRadius: 16))
            }
        }
    }

    // MARK: - Pieces

    /// A finished quest shows the pet right at the front, even if the minutes went over.
    private var shownFraction: Double { progress.isComplete ? 1 : progress.fraction * 0.85 }

    private var title: String { progress.isComplete ? "\(pet.name) is back!" : "\(pet.name) ran away" }

    private var explanation: String {
        if progress.isComplete {
            return "All that moving brought \(pet.name) all the way home. Say hello!"
        }
        let steps = progress.stepsRemaining.formatted()
        return "Pets never leave for good. \(progress.minutesRemaining) more active minutes brings \(pet.name) "
            + "home: a workout, or about \(steps) everyday steps. Every bit of it, \(pet.name) walks a little closer."
    }

    /// The way home as a pill that fills up, with a paw at the front of the fill.
    private var meter: some View {
        GeometryReader { geometry in
            let filled = max(geometry.size.height, geometry.size.width * progress.fraction)
            ZStack(alignment: .leading) {
                Capsule().fill(compact ? AnyShapeStyle(.black.opacity(0.35)) : AnyShapeStyle(.quaternary))
                Capsule().fill(FitchiTheme.Colors.accent).frame(width: filled)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: geometry.size.height * 0.6, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: geometry.size.height)
                    .offset(x: filled - geometry.size.height)
            }
        }
        .frame(height: compact ? 12 : 16)
        .animation(.easeOut, value: progress.fraction)
        .accessibilityElement(children: .ignore)
            .accessibilityLabel("Way home")
            .accessibilityValue("\(progress.minutesRemaining) active minutes to go")
    }

    private var welcomeButton: some View {
        Button(action: onWelcome) {
            Label("Welcome home", systemImage: "house.fill")
                .font(FitchiTheme.Fonts.display(compact ? .footnote : .headline))
                .padding(.horizontal, compact ? 4 : 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(FitchiTheme.Colors.accent)
        .padding(.bottom, compact ? 6 : 0)
    }
}

/// The empty scene with the pet on its way back: tiny and hazy on the horizon at 0, at the
/// front of the ground and in full colour at 1. A gentle walking bob unless Reduce Motion is on.
struct ComebackScene: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let pet: Pet
    let species: Species?
    let backdrop: SceneBackdrop.Kind
    let fraction: Double
    /// Pet width as a fraction of the scene width once it's at the front.
    let frontScale: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            TimelineView(.animation(minimumInterval: 1.0 / 12, paused: isLuminanceReduced)) { timeline in
                let date = timeline.date
                let season = Season(at: date)
                let clock = reduceMotion ? 0 : date.timeIntervalSinceReferenceDate
                let near = CGFloat(fraction)
                let petSize = size.width * (0.08 + (frontScale - 0.08) * near)
                // Ground runs from just below the horizon (width × 0.6) to near the bottom edge.
                let backFeet = size.width * 0.6
                let frontFeet = min(size.height - size.width * 0.05, size.width * 0.98)
                let feet = backFeet + (frontFeet - backFeet) * near
                let bob = fraction < 1 ? abs(sin(clock * 5)) * petSize * 0.05 : 0
                ZStack {
                    SceneBackdrop(
                        backdrop, time: clock, light: SceneLight(at: date), season: season,
                        weather: Weather(at: date, season: season))
                    LivingPetView(
                        species: species, speciesID: pet.speciesID, variant: pet.variant, excited: fraction >= 1,
                        seed: pet.id, accessories: pet.equipped, framesPerSecond: 12
                    )
                    .frame(width: petSize, height: petSize)
                    .saturation(0.35 + 0.65 * fraction)
                    .opacity(0.6 + 0.4 * fraction)
                    .position(x: size.width * (0.68 - 0.18 * near), y: feet - petSize / 2 - bob)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(fraction >= 1 ? "\(pet.name) is home, waiting for you" : "\(pet.name), far away")
    }
}

public extension PetStage {
    /// The next time a stage appears, the pet runs to the front for a big hello, as if you'd
    /// been away for hours (a pet that just came home).
    static func bigHelloNext() {
        UserDefaults.standard.set(0.0, forKey: lastSeenKey)
    }
}
