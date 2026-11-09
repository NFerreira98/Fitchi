import SwiftUI

/// Design tokens shared by every Fitchi surface. Prefer these over hard-coded values.
public enum FitchiTheme {
    public enum Colors {
        public static let accent = Color(red: 1.0, green: 0.55, blue: 0.35)
        public static let hunger = Color.orange
        public static let happiness = Color.pink
        public static let energy = Color.mint
        public static let points = Color.yellow
    }

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let s: CGFloat = 8
        public static let m: CGFloat = 12
        public static let l: CGFloat = 16
    }
}
