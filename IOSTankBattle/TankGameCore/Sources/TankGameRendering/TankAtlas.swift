import SpriteKit
import TankGameCore

/// One frame in the atlas: where it is in the image, and where its hull centre
/// sits inside it.
public struct AtlasFrame: Equatable, Sendable {
    /// Pixels, with a TOP-LEFT origin, exactly as the JSON states them.
    public let rect: CGRect
    /// SpriteKit `anchorPoint` units (0…1, origin bottom-left). Setting this on
    /// the sprite puts the tank's hull centre on the sprite's position, so the
    /// hull lands on the tile and the barrel overhangs.
    public let anchor: CGPoint

    public init(rect: CGRect, anchor: CGPoint) {
        self.rect = rect
        self.anchor = anchor
    }
}

/// The frames of one tank, from the atlas's `up` row.
///
/// Only `up` is used. The other three direction rows draw the hull facing up
/// anyway and are inconsistent about the barrel — `down` runs it straight
/// through the hull and flashes at the wrong end — so facing is done by
/// rotating the sprite instead. See `docs/sprite_design.md` (F1).
public enum TankAnimation: String, CaseIterable, Sendable {
    case idle, move1, move2, move3, fire, destroyed

    /// The loop played while a tank drives, there and back so it does not jump.
    public static let driving: [TankAnimation] = [.move1, .move2, .move3, .move2]
}

/// Reads `tank_atlas.json` / `tank_atlas.png` from a bundle and vends
/// sub-textures of the single parent texture, so the whole board batches.
///
/// Returns `nil` from `init` when the atlas is not in the bundle, which is the
/// normal case for the test bundle: `SpriteCatalog` then falls back to the
/// placeholder shapes, and a missing atlas can never crash the game.
@MainActor
public final class TankAtlas {

    /// The atlas's own file name, without extension.
    public static let resourceName = "tank_atlas"

    public let imageSize: CGSize
    private let parent: SKTexture
    private let cgImage: CGImage
    private let tanks: [String: [String: [String: AtlasFrame]]]   // set -> direction -> frame
    private let projectiles: [String: [AtlasFrame]]
    private let sequences: [String: [AtlasFrame]]                 // explosion / smoke / crater
    private let icons: [String: AtlasFrame]
    private var hullWidths: [String: CGFloat] = [:]
    private var textureCache: [String: SKTexture] = [:]

    public init?(bundle: Bundle) {
        guard let jsonURL = bundle.url(forResource: Self.resourceName, withExtension: "json"),
              let imageURL = bundle.url(forResource: Self.resourceName, withExtension: "png"),
              let data = try? Data(contentsOf: jsonURL),
              let file = try? JSONDecoder().decode(AtlasFile.self, from: data),
              let imageData = try? Data(contentsOf: imageURL),
              let image = PlatformImage(data: imageData),
              let cg = Self.cgImage(of: image) else { return nil }

        self.imageSize = CGSize(width: file.imageWidth, height: file.imageHeight)
        self.cgImage = cg
        self.parent = SKTexture(image: image)
        self.tanks = file.tanks.mapValues { directions in
            directions.mapValues { frames in frames.mapValues(\.frame) }
        }
        self.projectiles = file.effects.projectiles.mapValues { $0.map(\.frame) }
        self.sequences = [
            "explosion": file.effects.explosion.map(\.frame),
            "smoke": file.effects.smoke.map(\.frame),
            "crater": file.effects.crater.map(\.frame),
        ]
        self.icons = file.ui.mapValues(\.frame)
    }

    // MARK: - Lookup

    /// A tank frame from the `up` row, with the sub-texture to draw it with.
    public func texture(_ set: String, _ animation: TankAnimation) -> (SKTexture, AtlasFrame)? {
        guard let frame = tanks[set]?["up"]?[animation.rawValue] else { return nil }
        return (subTexture(frame.rect, key: "\(set).\(animation.rawValue)"), frame)
    }

    /// One frame of a projectile (`bullet`, `mediumShell`, `rocket`, `laser`).
    /// The index wraps, so callers can cycle without knowing the frame count.
    public func projectile(_ name: String, frame index: Int) -> (SKTexture, CGSize)? {
        guard let frames = projectiles[name], !frames.isEmpty else { return nil }
        let frame = frames[((index % frames.count) + frames.count) % frames.count]
        return (subTexture(frame.rect, key: "proj.\(name).\(index)"), frame.rect.size)
    }

    /// One frame of `explosion`, `smoke` or `crater`.
    public func effect(_ name: String, frame index: Int) -> (SKTexture, CGSize)? {
        guard let frames = sequences[name], frames.indices.contains(index) else { return nil }
        let frame = frames[index]
        return (subTexture(frame.rect, key: "fx.\(name).\(index)"), frame.rect.size)
    }

    public func effectFrameCount(_ name: String) -> Int { sequences[name]?.count ?? 0 }

    /// A UI icon (`crate`, `medkit`, `flagGreen`, …).
    public func icon(_ name: String) -> (SKTexture, CGSize)? {
        guard let frame = icons[name] else { return nil }
        return (subTexture(frame.rect, key: "ui.\(name)"), frame.rect.size)
    }

    public var tankSets: [String] { Array(tanks.keys).sorted() }

    // MARK: - Hull measurement

    /// The width in pixels of the widest solid row of a set's `idle` frame.
    ///
    /// Scaling is driven off the hull rather than the frame (`docs/sprite_design.md`
    /// D5) because frames vary in size — the wreck is up to 11 px wider than the
    /// idle pose — and a tank that changed size when it fired would look wrong.
    /// Measured from the pixels so a new atlas needs no new constants.
    public func hullWidth(of set: String) -> CGFloat {
        if let cached = hullWidths[set] { return cached }
        guard let frame = tanks[set]?["up"]?[TankAnimation.idle.rawValue] else { return 0 }
        let width = Self.widestSolidRow(of: frame.rect, in: cgImage)
        hullWidths[set] = width
        return width
    }

    // MARK: - Internals

    private func subTexture(_ rect: CGRect, key: String) -> SKTexture {
        if let cached = textureCache[key] { return cached }
        let texture = SKTexture(rect: Self.normalizedRect(rect, in: imageSize), in: parent)
        textureCache[key] = texture
        return texture
    }

    /// Converts a pixel rect with a TOP-LEFT origin — what the JSON uses — into
    /// the normalised, BOTTOM-LEFT rect `SKTexture(rect:in:)` wants.
    ///
    /// The y flip is the whole reason this is a named function with its own
    /// test: get it wrong and every sprite is a plausible-looking slice of the
    /// wrong part of the sheet.
    public static func normalizedRect(_ rect: CGRect, in imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        return CGRect(x: rect.minX / imageSize.width,
                      y: 1 - (rect.minY + rect.height) / imageSize.height,
                      width: rect.width / imageSize.width,
                      height: rect.height / imageSize.height)
    }

    /// Widest run of opaque pixels in any row of `rect`. The tracks are the
    /// widest part of a top-down tank, so this is the hull's footprint; the
    /// barrel and the soft glow are too thin and too faint to count.
    static func widestSolidRow(of rect: CGRect, in image: CGImage) -> CGFloat {
        let x0 = Int(rect.minX), y0 = Int(rect.minY)
        let w = Int(rect.width), h = Int(rect.height)
        guard w > 0, h > 0 else { return 0 }

        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let slice = image.cropping(to: CGRect(x: x0, y: y0, width: w, height: h))
        else { return 0 }
        ctx.draw(slice, in: CGRect(x: 0, y: 0, width: w, height: h))

        var widest = 0
        for row in 0..<h {
            var first = -1, last = -1
            for column in 0..<w where pixels[(row * w + column) * 4 + 3] > 128 {
                if first < 0 { first = column }
                last = column
            }
            if first >= 0 { widest = max(widest, last - first + 1) }
        }
        return CGFloat(widest)
    }

    static func cgImage(of image: PlatformImage) -> CGImage? {
        #if canImport(UIKit)
        return image.cgImage
        #else
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #endif
    }
}

// MARK: - The JSON, as the file is written

/// Mirrors `tank_atlas.json` v2.0. Decoding is deliberately strict: a shape the
/// game does not understand should fail `init?` and fall back to placeholders
/// rather than render half an atlas.
private struct AtlasFile: Decodable {
    let imageWidth: Int
    let imageHeight: Int
    let tanks: [String: [String: [String: Entry]]]
    let effects: Effects
    let ui: [String: Entry]

    struct Effects: Decodable {
        let projectiles: [String: [Entry]]
        let explosion: [Entry]
        let smoke: [Entry]
        let crater: [Entry]
    }

    struct Entry: Decodable {
        let x: Int, y: Int, w: Int, h: Int
        /// Only tank frames carry an anchor; effects and icons are centred.
        let anchor: [Double]?

        var frame: AtlasFrame {
            AtlasFrame(rect: CGRect(x: x, y: y, width: w, height: h),
                       anchor: CGPoint(x: anchor?.first ?? 0.5, y: anchor?.last ?? 0.5))
        }
    }
}
