// swift-tools-version: 6.2
// FitchiHealth — HealthKit adapter. Reads workouts / active energy / exercise minutes and
// maps them into FitchiCore types. The only package allowed to import HealthKit.
import PackageDescription

let package = Package(
    name: "FitchiHealth",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "FitchiHealth", targets: ["FitchiHealth"]),
    ],
    dependencies: [
        .package(path: "../FitchiCore"),
    ],
    targets: [
        .target(name: "FitchiHealth", dependencies: ["FitchiCore"]),
    ]
)
