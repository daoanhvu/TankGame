// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TankGameCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "TankGameCore", targets: ["TankGameCore"])
    ],
    targets: [
        .target(name: "TankGameCore"),
        .testTarget(name: "TankGameCoreTests", dependencies: ["TankGameCore"])
    ]
)
