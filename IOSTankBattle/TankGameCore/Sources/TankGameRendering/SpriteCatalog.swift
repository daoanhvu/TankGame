import SpriteKit
import TankGameCore

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

/// Colors used when an image asset is missing (stage 1 "shapes only" art).
public struct PlaceholderPalette {
    public var sideColors: [Side: SKColor]
    public var terrainColors: [Terrain: SKColor]
    public var gridLineColor: SKColor
    public var labelColor: SKColor

    public init(sideColors: [Side: SKColor], terrainColors: [Terrain: SKColor],
                gridLineColor: SKColor, labelColor: SKColor) {
        self.sideColors = sideColors
        self.terrainColors = terrainColors
        self.gridLineColor = gridLineColor
        self.labelColor = labelColor
    }

    public static var standard: PlaceholderPalette {
        PlaceholderPalette(
            sideColors: [
                .player: SKColor(red: 0.20, green: 0.45, blue: 0.90, alpha: 1), // blue
                .ai:     SKColor(red: 0.85, green: 0.25, blue: 0.20, alpha: 1), // red
            ],
            terrainColors: [
                .open:  SKColor(red: 0.231, green: 0.302, blue: 0.212, alpha: 1), // olive field
                .trees: SKColor(red: 0.133, green: 0.204, blue: 0.129, alpha: 1), // dark wood
                .rocks: SKColor(red: 0.278, green: 0.282, blue: 0.251, alpha: 1), // stone
                .water: SKColor(red: 0.149, green: 0.278, blue: 0.333, alpha: 1), // deep water
            ],
            gridLineColor: SKColor(white: 1, alpha: 0.05),
            labelColor: .white
        )
    }

    public func color(for side: Side) -> SKColor { sideColors[side] ?? .gray }
    public func color(for terrain: Terrain) -> SKColor { terrainColors[terrain] ?? .magenta }
}

/// Builds SpriteKit nodes for game objects.
///
/// Looks up images by `AssetName`. If an image is missing, it returns a
/// placeholder shape instead, so a partial art set never breaks the game.
/// Rendering code should ALWAYS create visuals through this catalog,
/// never with `SKSpriteNode(imageNamed:)` directly.
///
/// Returned nodes are centered on (0, 0) and sized to `tileSize`;
/// the caller positions them on the grid.
@MainActor
public final class SpriteCatalog {

    /// Child node names, so other code (animations, tests) can find parts.
    public enum NodeName {
        public static let body = "body"
        public static let barrel = "barrel"
        public static let placeholder = "placeholder"
    }

    public let tileSize: CGFloat
    public let palette: PlaceholderPalette
    /// The sprite sheet tanks and effects come from, or nil when it is not in
    /// the bundle — in which case everything falls back to placeholder shapes.
    public let atlas: TankAtlas?
    private let bundle: Bundle
    private var cache: [String: SKTexture] = [:]
    private var missing: Set<String> = []

    public init(tileSize: CGFloat = 64,
                bundle: Bundle = .main,
                palette: PlaceholderPalette = .standard,
                atlas: TankAtlas? = nil) {
        self.tileSize = tileSize
        self.bundle = bundle
        self.palette = palette
        self.atlas = atlas ?? TankAtlas(bundle: bundle)
    }

    // MARK: - Texture lookup

    /// The texture for `name`, or nil if no such image exists.
    /// (Note: `SKTexture(imageNamed:)` never returns nil, it shows a red
    /// placeholder, which is why we check for the image ourselves.)
    public func texture(named name: String) -> SKTexture? {
        if let cached = cache[name] { return cached }
        if missing.contains(name) { return nil }
        guard let image = Self.loadImage(named: name, in: bundle) else {
            missing.insert(name)
            return nil
        }
        let texture = SKTexture(image: image)
        cache[name] = texture
        return texture
    }

    /// Required assets that are not in the bundle yet: a live to-do list for art.
    public func missingRequiredAssets() -> [String] {
        AssetName.required.filter { texture(named: $0) == nil }
    }

    private static func loadImage(named name: String, in bundle: Bundle) -> PlatformImage? {
        #if canImport(UIKit)
        return UIImage(named: name, in: bundle, compatibleWith: nil)
        #else
        return bundle.image(forResource: name)
        #endif
    }

    // MARK: - Tanks

    public func tankNode(for tank: Tank) -> SKNode {
        tankNode(kind: tank.kind, side: tank.side)
    }

    public func tankNode(kind: TankKind, side: Side) -> SKNode {
        let container = SKNode()
        let size = CGSize(width: tileSize * 0.85, height: tileSize * 0.85)

        if let body = atlasHull(kind: kind, side: side) {
            container.addChild(body)
            return container
        }

        if let hull = texture(named: AssetName.tank(kind, side)) {
            let body = SKSpriteNode(texture: hull, size: size)
            body.name = NodeName.body
            container.addChild(body)

            if let barrelTexture = texture(named: AssetName.tankBarrel(kind, side)) {
                let barrel = SKSpriteNode(texture: barrelTexture)
                barrel.size = scaled(barrelTexture.size(), toMatchHull: hull.size(), hullDisplaySize: size)
                barrel.name = NodeName.barrel
                barrel.zPosition = 1
                body.addChild(barrel)
            }
            // Sprites face up; AI tanks start facing the player (down).
            if side == .ai { body.zRotation = .pi }
        } else {
            container.addChild(placeholderTank(kind: kind, side: side, size: size))
        }
        return container
    }

    /// The hull from the atlas, sized off its own measured hull width so every
    /// frame of a set shares one scale (`docs/sprite_design.md` D5), and
    /// anchored on the hull centre so the tank sits on its tile with the barrel
    /// overhanging.
    ///
    /// The atlas art is drawn facing up, so AI tanks are rotated to face the
    /// player, as the placeholder art already was.
    private func atlasHull(kind: TankKind, side: Side) -> SKSpriteNode? {
        guard let atlas else { return nil }
        let set = TankSkin.atlasSet(for: side)
        guard let (texture, frame) = atlas.texture(set, .idle) else { return nil }

        let hullWidth = atlas.hullWidth(of: set)
        guard hullWidth > 0 else { return nil }
        let scale = TankSkin.hullFraction(for: kind) * tileSize / hullWidth

        let sprite = SKSpriteNode(texture: texture,
                                  size: CGSize(width: frame.rect.width * scale,
                                               height: frame.rect.height * scale))
        sprite.anchorPoint = frame.anchor
        sprite.name = NodeName.body
        if side == .ai { sprite.zRotation = .pi }
        return sprite
    }

    private func placeholderTank(kind: TankKind, side: Side, size: CGSize) -> SKNode {
        let shape = SKShapeNode(rectOf: size, cornerRadius: size.width * 0.2)
        shape.name = NodeName.placeholder
        shape.fillColor = palette.color(for: side)
        shape.strokeColor = palette.labelColor
        shape.lineWidth = 2

        let label = SKLabelNode(fontNamed: "Helvetica-Bold")
        label.text = String(kind.rawValue.prefix(1)).uppercased() // L / M / A
        label.fontSize = tileSize * 0.4
        label.fontColor = palette.labelColor
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        shape.addChild(label)
        return shape
    }

    /// Keeps the barrel's proportions relative to the hull it was drawn for.
    private func scaled(_ barrelSize: CGSize, toMatchHull hullSize: CGSize,
                        hullDisplaySize: CGSize) -> CGSize {
        guard hullSize.width > 0, hullSize.height > 0 else { return barrelSize }
        return CGSize(width: barrelSize.width * hullDisplaySize.width / hullSize.width,
                      height: barrelSize.height * hullDisplaySize.height / hullSize.height)
    }

    // MARK: - Terrain and supply tiles

    public func terrainNode(_ terrain: Terrain) -> SKNode {
        let size = CGSize(width: tileSize, height: tileSize)
        if let texture = texture(named: AssetName.terrain(terrain)) {
            let sprite = SKSpriteNode(texture: texture, size: size)
            sprite.name = NodeName.body
            return sprite
        }
        let shape = SKShapeNode(rectOf: size)
        shape.name = NodeName.placeholder
        shape.fillColor = palette.color(for: terrain)
        shape.strokeColor = palette.gridLineColor
        shape.lineWidth = 1
        return shape
    }

    /// An overlay drawn on top of the supply tile's open-ground terrain.
    public func supplyNode(_ side: Side) -> SKNode {
        let size = CGSize(width: tileSize * 0.8, height: tileSize * 0.8)
        if let texture = texture(named: AssetName.supply(side)) {
            let sprite = SKSpriteNode(texture: texture, size: size)
            sprite.name = NodeName.body
            return sprite
        }
        let shape = SKShapeNode(rectOf: size, cornerRadius: 4)
        shape.name = NodeName.placeholder
        shape.fillColor = .clear
        shape.strokeColor = palette.color(for: side)
        shape.lineWidth = 3

        let plus = SKLabelNode(fontNamed: "Helvetica-Bold")
        plus.text = "+"
        plus.fontSize = tileSize * 0.5
        plus.fontColor = palette.color(for: side)
        plus.verticalAlignmentMode = .center
        plus.horizontalAlignmentMode = .center
        shape.addChild(plus)
        return shape
    }

    // MARK: - Effects

    /// Effects have no placeholder; callers can skip or use a simple
    /// SKAction (e.g. a scaling circle) when this returns nil.
    public func effectTexture(_ effect: AssetName.Effect) -> SKTexture? {
        texture(named: AssetName.effect(effect))
    }
}
