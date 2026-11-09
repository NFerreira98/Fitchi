// swift-tools-version: 6.2
// FitchiData — SwiftData models + repositories, synced via CloudKit (private DB).
// CloudKit rules: every stored property optional or defaulted, no @Attribute(.unique),
// all relationships optional. De-duplication lives in the repository layer.
import PackageDescription

let package = Package(
    name: "FitchiData",
    platforms: [.iOS(.v26), .watchOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "FitchiData", targets: ["FitchiData"]),
    ],
    dependencies: [
        .package(path: "../FitchiCore"),
    ],
    targets: [
        .target(name: "FitchiData", dependencies: ["FitchiCore"]),
        .testTarget(name: "FitchiDataTests", dependencies: ["FitchiData"]),
    ]
)
