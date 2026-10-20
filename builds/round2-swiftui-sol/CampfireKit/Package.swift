// swift-tools-version: 6.0
import PackageDescription

// Shared data model, seeded fake data and fake live feed for the Campfire UIKit / SwiftUI comparison.
// No UI framework is imported here on purpose: both builds share this file set unchanged.
// CampfireKitObjC is an Objective-C-facing bridge over CampfireKit for the V2 Objective-C UIKit build.
let package = Package(
    name: "CampfireKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CampfireKit", targets: ["CampfireKit"]),
        .library(name: "CampfireKitObjC", targets: ["CampfireKitObjC"]),
    ],
    targets: [
        .target(name: "CampfireKit"),
        .target(name: "CampfireKitObjC", dependencies: ["CampfireKit"]),
        .testTarget(name: "CampfireKitTests", dependencies: ["CampfireKit"]),
        .testTarget(name: "CampfireKitObjCTests", dependencies: ["CampfireKitObjC", "CampfireKit"]),
    ]
)
