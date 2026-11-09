import SwiftUI

/// Stand-in pet used until the layered sprite renderer exists (Milestone 5).
public struct PetPlaceholderView: View {
    private let name: String

    public init(name: String) {
        self.name = name
    }

    public var body: some View {
        VStack(spacing: FitchiTheme.Spacing.s) {
            Text("🐣")
                .font(.system(size: 56))
                .accessibilityHidden(true)
            Text(name)
                .font(.headline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your pet, \(name)")
    }
}

#Preview {
    PetPlaceholderView(name: "Mochi")
}
