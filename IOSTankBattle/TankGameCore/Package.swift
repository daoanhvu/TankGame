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
        // The opponent's brain. Depends on the core only, so it can be swapped
        // or upgraded (minimax, difficulty levels) without touching the rules
        // or the renderer.
        .library(name: "TankGameAI", targets: ["TankGameAI"]),
    ],
    targets: [
        .target(name: "TankGameCore"),
        // Rendering -> AI -> Core, never back the other way: the scene has to
        // schedule the opponent's turns, so it needs the brain's protocol.
        .target(name: "TankGameRendering", dependencies: ["TankGameCore", "TankGameAI"]),
        .target(name: "TankGameAI", dependencies: ["TankGameCore"]),
        .testTarget(name: "TankGameCoreTests", dependencies: ["TankGameCore"]),
        .testTarget(name: "TankGameRenderingTests", dependencies: ["TankGameRendering", "TankGameCore", "TankGameAI"]),
        .testTarget(name: "TankGameAITests", dependencies: ["TankGameAI", "TankGameCore"]),
    ]
)
