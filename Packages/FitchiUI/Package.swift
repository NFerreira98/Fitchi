// swift-tools-version: 6.2
// FitchiUI — shared SwiftUI components (pet rendering, stat bars, item cards, theme)
// used by both the watch and phone apps.
import PackageDescription

let package = Package(
    name: "FitchiUI",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "FitchiUI", targets: ["FitchiUI"]),
    ],
    dependencies: [
        .package(path: "../FitchiCore"),
    ],
    targets: [
        .target(name: "FitchiUI", dependencies: ["FitchiCore"]),
    ]
)
