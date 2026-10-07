// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TankGameCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        // Pure rules engine. No UIKit/AppKit/SpriteKit allowed in this target.
        .library(name: "TankGameCore", targets: ["TankGameCore"]),
        // SpriteKit-facing helpers (art lookup, placeholders). Depends on the core, never the reverse.
        .library(name: "TankGameRendering", targets: ["TankGameRendering"]),
    ],
    targets: [
        .target(name: "TankGameCore"),
        .target(name: "TankGameRendering", dependencies: ["TankGameCore"]),
        .testTarget(name: "TankGameCoreTests", dependencies: ["TankGameCore"]),
        .testTarget(name: "TankGameRenderingTests", dependencies: ["TankGameRendering", "TankGameCore"]),
    ]
)
