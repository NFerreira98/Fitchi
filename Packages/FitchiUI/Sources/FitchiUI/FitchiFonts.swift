import CoreText
import SwiftUI

public extension FitchiTheme {
    /// Two typefaces:
    /// - **Baloo 2** (`display`) for personality: pet names, Pep numbers, buttons, big moments.
    /// - **SF Pro Rounded** (`text`) for everything you read: hints, status lines, lists.
    ///
    /// Both scale with Dynamic Type. Call `Fonts.register()` once at app launch.
    enum Fonts {
        static let displayFamily = "Baloo 2"

        /// Registers the bundled Baloo 2 font with the process. Safe to call more than once.
        public static func register() {
            _ = registration
        }

        private static let registration: Bool = {
            guard
                let url = Bundle.module.url(forResource: "Baloo2-Variable", withExtension: "ttf", subdirectory: "Fonts")
            else {
                assertionFailure("Baloo 2 is missing from the FitchiUI bundle")
                return false
            }
            return CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }()

        /// Baloo 2 at a Dynamic Type style's size. Baloo has tall line spacing, so keep it to single
        /// lines (names, numbers, buttons, headlines).
        public static func display(_ style: Font.TextStyle = .headline, weight: Font.Weight = .bold) -> Font {
            Font.custom(displayFamily, size: baseSize(for: style), relativeTo: style).weight(weight)
        }

        /// Baloo 2 at a fixed size, for hero moments ("It's a Shiny!").
        public static func display(size: CGFloat, weight: Font.Weight = .heavy) -> Font {
            Font.custom(displayFamily, size: size).weight(weight)
        }

        /// SF Pro Rounded for running text.
        public static func text(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
            .system(style, design: .rounded, weight: weight)
        }

        /// Default point sizes per text style; Dynamic Type scales from these. Watch sizes are smaller.
        private static func baseSize(for style: Font.TextStyle) -> CGFloat {
            #if os(watchOS)
                let sizes: [Font.TextStyle: CGFloat] = [
                    .largeTitle: 32, .title: 26, .title2: 22, .title3: 20, .headline: 17,
                    .body: 16, .callout: 15, .subheadline: 14, .footnote: 13, .caption: 12, .caption2: 11,
                ]
            #else
                let sizes: [Font.TextStyle: CGFloat] = [
                    .largeTitle: 34, .title: 28, .title2: 22, .title3: 20, .headline: 17,
                    .body: 17, .callout: 16, .subheadline: 15, .footnote: 13, .caption: 12, .caption2: 11,
                ]
            #endif
            return sizes[style] ?? 17
        }
    }
}
