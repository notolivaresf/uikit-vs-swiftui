// swift-tools-version: 6.0
import PackageDescription

// Writes the CampfireKit people and messages that the screenshot comparison shows as JSON, plus the
// placeholder images as PNG files, so the ONCE Campfire reference can be seeded with the same data.
//   swift run --package-path Harness/ExportFixture export-fixture <out dir>
let package = Package(
    name: "ExportFixture",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../../CampfireKit")],
    targets: [.executableTarget(name: "export-fixture", dependencies: ["CampfireKit"])]
)
