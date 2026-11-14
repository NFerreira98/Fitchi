import FitchiCore
import FitchiData
import FitchiUI
import SwiftUI

/// The first-run guide on the iPhone: what Fitchi is, how Pep is earned, how care works, and
/// why it asks for Health. Shown once to new players before the Health prompt (finishing it
/// starts `ActivityStore`, which asks), and again any time from Home ("How Fitchi works").
struct WelcomeView: View {
    /// `UserDefaults` key: the guide has been seen (set for existing players at launch too).
    static let seenKey = "fitchi.welcomed"

    @Environment(PetStore.self) private var pets
    /// First run: the last page asks for Health. Otherwise it just closes.
    var isFirstRun = true
    let onFinish: () -> Void
    /// In the simulator, `-welcomePage 2` (etc.) at launch opens that page, for screenshots.
    @State private var page =
        ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil
        ? 0 : UserDefaults.standard.integer(forKey: "welcomePage")

    private static let pages = 4

    var body: some View {
        VStack(spacing: FitchiTheme.Spacing.l) {
            TabView(selection: $page) {
                meet.tag(0)
                pep.tag(1)
                care.tag(2)
                health.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.snappy, value: page)

            Button {
                if page < Self.pages - 1 { page += 1 } else { onFinish() }
            } label: {
                Text(buttonTitle)
                    .font(FitchiTheme.Fonts.display(.headline))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(FitchiTheme.Colors.accent)
            .padding(.horizontal, FitchiTheme.Spacing.l)
            .padding(.bottom, FitchiTheme.Spacing.m)
            .sensoryFeedback(.selection, trigger: page)
        }
        .background(Color(.systemBackground))
    }

    private var buttonTitle: String {
        guard page == Self.pages - 1 else { return "Next" }
        return isFirstRun ? "Connect to Health" : "Got it"
    }

    // MARK: - Pages

    private var meet: some View {
        WelcomePage(
            title: "Meet your Fitchi",
            text: "A little pet that grows with you. It lives on your iPhone, and on your Apple Watch if you "
                + "wear one. It starts as an egg, and moving is what hatches it."
        ) {
            EggFigure()
                .frame(width: 110, height: 110)
                .phaseAnimator([-6.0, 6.0]) { egg, angle in
                    egg.rotationEffect(.degrees(angle), anchor: .bottom)
                } animation: { _ in
                    .easeInOut(duration: 0.8)
                }
                .padding(.bottom, 26)
        }
    }

    private var pep: some View {
        WelcomePage(
            title: "Move to earn Pep",
            text: "Pep (✦) buys food, toys, new eggs and outfits. Everyday steps earn it, a walk or run "
                + "earns more, and your pet finds little gifts a few times a day."
        ) {
            VStack(spacing: 12) {
                Text("✦ Pep")
                    .font(FitchiTheme.Fonts.display(size: 34, weight: .bold))
                    .foregroundStyle(FitchiTheme.Colors.points)
                    .shadow(color: .black.opacity(0.25), radius: 3)
                HStack(spacing: 14) {
                    badge("🚶", "Steps")
                    badge("🏃", "Workouts")
                    badge("🎁", "Gifts")
                }
            }
            .padding(.bottom, 24)
        }
    }

    private var care: some View {
        WelcomePage(
            title: "Look after it",
            text: "Food, fun, energy and cleanliness run down slowly (more slowly at night). Tap Feed, Play, "
                + "Wash or Rest to help. Leave it alone for days and it gets sick and may run away, but "
                + "pets never leave for good: a good walk brings them home."
        ) {
            VStack(spacing: 10) {
                if let dog = pets.catalog.species(id: "dog") {
                    LivingPetView(species: dog, speciesID: dog.id, variant: nil, excited: true, seedValue: 2)
                        .frame(width: 96, height: 96)
                }
                HStack(spacing: 8) {
                    ForEach([CareAction.feed, .play, .wash, .rest], id: \.self) { action in
                        Text(action.emoji)
                            .font(.system(size: 22))
                            .frame(width: 42, height: 42)
                            .background(.thinMaterial, in: .circle)
                    }
                }
            }
            .padding(.bottom, 14)
        }
    }

    private var health: some View {
        WelcomePage(
            title: isFirstRun ? "Connect to Health" : "Your activity",
            text: "Fitchi reads your steps, workouts and exercise minutes from Apple Health to pay you Pep, "
                + "plus heart rate and age to tell how hard a workout was. It never writes to Health, and "
                + "everything stays on your iPhone (and Apple Watch): nothing goes online."
        ) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 76))
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(.pink, .white)
                .padding(.bottom, 34)
        }
    }

    private func badge(_ emoji: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 30))
            Text(label).font(FitchiTheme.Fonts.display(size: 13, weight: .semibold))
        }
        .frame(width: 84, height: 74)
        .background(.thinMaterial, in: .rect(cornerRadius: 16))
    }
}

/// One page of the guide: a little scene with something standing in it, a title and a few lines.
private struct WelcomePage<Art: View>: View {
    let title: String
    let text: String
    @ViewBuilder let art: Art

    var body: some View {
        VStack(alignment: .leading, spacing: FitchiTheme.Spacing.m) {
            SceneBackdrop(.meadow, light: .day)
                .aspectRatio(1.15, contentMode: .fit)
                .overlay(alignment: .bottom) { art }
                .clipShape(.rect(cornerRadius: 28))
            Text(title).font(FitchiTheme.Fonts.display(.largeTitle))
            Text(text)
                .font(FitchiTheme.Fonts.text(.body))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, FitchiTheme.Spacing.l)
        .padding(.top, FitchiTheme.Spacing.l)
    }
}
