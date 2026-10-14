import XCTest
import SpriteKit
import ImageIO
import UniformTypeIdentifiers
import TankGameCore
@testable import TankGameRendering

// MARK: - Pixel helpers

private typealias RGB = (r: UInt8, g: UInt8, b: UInt8)
private let red: RGB = (255, 0, 0)
private let green: RGB = (0, 255, 0)
private let blue: RGB = (0, 0, 255)

/// An opaque image whose pixel at (x, y), counted from the TOP-LEFT, is `color(x, y)`.
private func makeImage(width: Int, height: Int, _ color: (Int, Int) -> RGB) -> CGImage {
    var bytes = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let c = color(x, y)
            let i = (y * width + x) * 4
            (bytes[i], bytes[i + 1], bytes[i + 2]) = (c.r, c.g, c.b)
        }
    }
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                   bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}

/// The pixel at (x, y), counted from the TOP-LEFT.
private func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> RGB {
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    let context = CGContext(data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8,
                            bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let i = (y * image.width + x) * 4
    return (bytes[i], bytes[i + 1], bytes[i + 2])
}

private func XCTAssertColor(_ actual: RGB, _ expected: RGB, _ message: String = "",
                            file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(actual == expected, "\(actual) is not \(expected). \(message)", file: file, line: line)
}

// MARK: - Composing

final class TiledArtTests: XCTestCase {

    /// A map of 4 x 4 px tiles, `width` cells wide and one high, drawing from a
    /// one-column tileset of `tileCount` tiles.
    private func tiledMap(width: Int = 2, layers: [[UInt32]], visible: [Bool]? = nil,
                          tileCount: Int = 2) throws -> TiledMap {
        let layerObjects: [[String: Any]] = layers.enumerated().map { index, gids in
            ["name": "L\(index)", "type": "tilelayer", "data": gids, "visible": visible?[index] ?? true]
        }
        let tileset: [String: Any] = ["firstgid": 1, "name": "Test set", "columns": 1, "tilecount": tileCount,
                                      "tilewidth": 4, "tileheight": 4,
                                      "imagewidth": 4, "imageheight": 4 * tileCount]
        let json: [String: Any] = ["width": width, "height": 1, "tilewidth": 4, "tileheight": 4,
                                   "layers": layerObjects, "tilesets": [tileset]]
        return try TiledMap(json: JSONSerialization.data(withJSONObject: json)) { _ in Data() }
    }

    /// Tile 0 solid red, tile 1 solid blue.
    private let solidSheet = makeImage(width: 4, height: 8) { _, y in y < 4 ? red : blue }

    func testTilesLandInTheirCells() throws {
        let map = try tiledMap(layers: [[1, 2]])
        let art = try XCTUnwrap(TiledArt.compose(map) { _ in self.solidSheet })
        XCTAssertEqual(art.width, 8)
        XCTAssertEqual(art.height, 4)
        XCTAssertColor(pixel(art, 1, 1), red)
        XCTAssertColor(pixel(art, 5, 1), blue)
    }

    func testUpperLayersCoverLowerOnes() throws {
        let map = try tiledMap(layers: [[1, 1], [0, 2]])
        let art = try XCTUnwrap(TiledArt.compose(map) { _ in self.solidSheet })
        XCTAssertColor(pixel(art, 1, 1), red, "Nothing on top of the first cell")
        XCTAssertColor(pixel(art, 5, 1), blue)
    }

    func testHiddenLayersAreSkipped() throws {
        let map = try tiledMap(layers: [[1, 1], [2, 2]], visible: [true, false])
        let art = try XCTUnwrap(TiledArt.compose(map) { _ in self.solidSheet })
        XCTAssertColor(pixel(art, 5, 1), red)
    }

    func testMissingSheetGivesNoArt() throws {
        let map = try tiledMap(layers: [[1, 2]])
        XCTAssertNil(TiledArt.compose(map) { _ in nil })
    }

    /// Tile 0 is red on its left half and green on its right; tile 1 is red on
    /// its top half and green on its bottom.
    private let halvesSheet = makeImage(width: 4, height: 8) { x, y in
        y < 4 ? (x < 2 ? red : green) : (y < 6 ? red : green)
    }

    func testFlipFlagsTurnTheTile() throws {
        let h: UInt32 = 0x8000_0000, v: UInt32 = 0x4000_0000, d: UInt32 = 0x2000_0000
        // Cell by cell: as drawn, flipped left-right, flipped top-bottom, swapped x/y.
        let map = try tiledMap(width: 4, layers: [[1, h | 1, v | 2, d | 2]])
        let art = try XCTUnwrap(TiledArt.compose(map) { _ in self.halvesSheet })

        XCTAssertColor(pixel(art, 0, 1), red, "plain: red left")
        XCTAssertColor(pixel(art, 3, 1), green, "plain: green right")
        XCTAssertColor(pixel(art, 4, 1), green, "flipped H: green left")
        XCTAssertColor(pixel(art, 7, 1), red, "flipped H: red right")
        XCTAssertColor(pixel(art, 9, 0), green, "flipped V: green top")
        XCTAssertColor(pixel(art, 9, 3), red, "flipped V: red bottom")
        XCTAssertColor(pixel(art, 12, 1), red, "swapped: red left")
        XCTAssertColor(pixel(art, 15, 1), green, "swapped: green right")
    }
}

// MARK: - On the board

@MainActor
final class MapArtBoardTests: XCTestCase {

    private var bundleURL: URL!

    /// A bundle holding stand-ins for the map's tileset images, since the
    /// test bundle itself has no images.
    private func tilesetBundle(for map: TiledMap) throws -> Bundle {
        bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MapArtBoardTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        for set in map.tilesets {
            let image = makeImage(width: set.imageWidth, height: set.imageHeight) { _, _ in green }
            let url = bundleURL.appendingPathComponent("\(AssetName.tileset(set.name)).png")
            let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(
                url as CFURL, UTType.png.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
        }
        return try XCTUnwrap(Bundle(url: bundleURL))
    }

    override func tearDownWithError() throws {
        if let bundleURL { try? FileManager.default.removeItem(at: bundleURL) }
    }

    private func placeholderCount(in node: SKNode) -> Int {
        var count = 0
        node.enumerateChildNodes(withName: "//\(SpriteCatalog.NodeName.placeholder)") { _, _ in count += 1 }
        return count
    }

    func testTilesetNamesFollowTheConventionAndAreOptional() {
        XCTAssertEqual(AssetName.tileset("Woodland essentials"), "tileset_woodland_essentials")
        XCTAssertEqual(AssetName.tileset("green_grass_bg_92"), "tileset_green_grass_bg_92")
        XCTAssertFalse(AssetName.required.contains { $0.hasPrefix("tileset_") })
    }

    /// With the tilesets there are no terrain tiles left to draw — only the
    /// tanks and the supply markers fall back to shapes.
    func testBoardDrawsTheMapArtInsteadOfTerrainTiles() throws {
        let (map, tiled) = try Maps.twinLakes()
        let state = try GameState.newGame(map: map)
        let catalog = SpriteCatalog(tileSize: 64, bundle: try tilesetBundle(for: tiled))
        let board = BoardNode(state: state, catalog: catalog, art: tiled)

        XCTAssertEqual(placeholderCount(in: board), state.tanks.count + 2)
        var artSprites = 0
        board.enumerateChildNodes(withName: "//\(SpriteCatalog.NodeName.body)") { node, _ in
            if (node as? SKSpriteNode)?.size == board.size { artSprites += 1 }
        }
        XCTAssertEqual(artSprites, 1)
    }

    /// Missing tileset images must never leave a blank board.
    func testBoardFallsBackToTerrainTilesWithoutTheTilesets() throws {
        let (map, tiled) = try Maps.twinLakes()
        let state = try GameState.newGame(map: map)
        let catalog = SpriteCatalog(tileSize: 64, bundle: Bundle(for: MapArtBoardTests.self))
        let board = BoardNode(state: state, catalog: catalog, art: tiled)

        let tiles = map.width * map.height
        XCTAssertEqual(placeholderCount(in: board), tiles + state.tanks.count + 2)
    }
}
