// swift-tools-version: 6.2
// FitchiCore — pure game rules. No Apple app frameworks (SwiftUI, HealthKit, SwiftData)
// may be imported here so the logic stays portable and testable with `swift test`.
import PackageDescription

let package = Package(
    name: "FitchiCore",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "FitchiCore", targets: ["FitchiCore"]),
    ],
    targets: [
        .target(name: "FitchiCore"),
        .testTarget(name: "FitchiCoreTests", dependencies: ["FitchiCore"]),
    ]
)
