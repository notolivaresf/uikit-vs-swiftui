// swift-tools-version: 5.9
import PackageDescription

// Round 5 shared package: the data (CampfireKit), the message row, the height measurer, the bottom pinning and
// the debug bar the harness reads. Every spike app links this and changes only the thing under test.
let package = Package(
    name: "SpikeKit",
    platforms: [.iOS(.v17)],
    products: [.library(name: "SpikeKit", targets: ["SpikeKit"])],
    dependencies: [.package(path: "../../../CampfireKit")],
    targets: [
        .target(name: "SpikeKit", dependencies: [.product(name: "CampfireKit", package: "CampfireKit")]),
    ]
)
