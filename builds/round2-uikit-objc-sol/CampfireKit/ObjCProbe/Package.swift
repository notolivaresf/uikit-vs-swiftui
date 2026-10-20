// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "ObjCProbe",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "..")],
    targets: [.executableTarget(name: "ObjCProbe", dependencies: [.product(name: "CampfireKitObjC", package: "CampfireKit")])]
)
