// swift-tools-version: 6.0
import PackageDescription

// Shared data model, seeded fake data and fake live feed for the Campfire UIKit / SwiftUI comparison.
// No UI framework is imported here on purpose: both builds share this file set unchanged.
let package = Package(
    name: "CampfireKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "CampfireKit", targets: ["CampfireKit"])],
    targets: [
        .target(name: "CampfireKit"),
        .testTarget(name: "CampfireKitTests", dependencies: ["CampfireKit"]),
    ]
)
