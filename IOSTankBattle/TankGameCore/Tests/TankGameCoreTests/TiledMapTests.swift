import XCTest
@testable import TankGameCore

final class TiledMapTests: XCTestCase {

    // MARK: - Helpers

    /// A minimal Tiled map: one tile layer per entry, each with optional gids
    /// and optional row-major `types`.
    private func tiledJSON(width: Int = 3, height: Int = 2,
                           layers: [(gids: [UInt32]?, types: [String]?)],
                           tilesets: [[String: Any]] = [],
                           infinite: Bool = false) -> Data {
        let layerObjects: [[String: Any]] = layers.enumerated().map { index, layer in
            var object: [String: Any] = ["name": "Layer \(index)", "type": "tilelayer",
                                         "data": layer.gids ?? Array(repeating: 0, count: width * height)]
            if let types = layer.types { object["types"] = types }
            return object
        }
        let map: [String: Any] = ["width": width, "height": height, "infinite": infinite,
                                  "tilewidth": 64, "tileheight": 64, "tilesets": tilesets,
                                  "layers": layerObjects]
        return try! JSONSerialization.data(withJSONObject: map)
    }

    private func tileset(name: String = "set", columns: Int = 2, count: Int = 4,
                         margin: Int = 0, spacing: Int = 0) -> [String: Any] {
        ["name": name, "columns": columns, "tilecount": count, "tilewidth": 64, "tileheight": 64,
         "margin": margin, "spacing": spacing,
         "imagewidth": columns * 64, "imageheight": (count / columns) * 64]
    }

    private func parse(_ data: Data, external: [String: [String: Any]] = [:]) throws -> TiledMap {
        try TiledMap(json: data) { source in
            guard let body = external[source] else { throw CocoaError(.fileNoSuchFile) }
            return try JSONSerialization.data(withJSONObject: body)
        }
    }

    private let supplies: [Side: Position] = [.ai: Position(x: 2, y: 0), .player: Position(x: 0, y: 1)]
    private let spawns: [Side: [Position]] = [.ai: [Position(x: 1, y: 0)], .player: [Position(x: 1, y: 1)]]

    private func map(_ types: [[String]?]) throws -> GameMap {
        try GameMap(tiled: parse(tiledJSON(layers: types.map { (nil, $0) })),
                    supplyTiles: supplies, spawnTiles: spawns)
    }

    // MARK: - Gameplay types

    func testTypesMapToTerrain() throws {
        let m = try map([["OPEN", "OPEN", "OPEN",
                          "OPEN", "OPEN", "NO_PASS"]])
        XCTAssertEqual(m.width, 3)
        XCTAssertEqual(m.height, 2)
        XCTAssertEqual(m.terrain(at: Position(x: 0, y: 0)), .open)
        XCTAssertEqual(m.terrain(at: Position(x: 2, y: 1)), .rocks)
        XCTAssertFalse(m.canEnter(Position(x: 2, y: 1), side: .player))
        XCTAssertEqual(m.supplyTiles, supplies)
        XCTAssertEqual(m.spawnTiles, spawns, "Spawns keep the given order for both sides")
    }

    func testEditorSpellingsAreAccepted() throws {
        let m = try map([["NO-PASSABLE", "OPEN", "OPEN",
                          "OPEN", "OPEN", "WATER"]])
        XCTAssertEqual(m.terrain(at: Position(x: 0, y: 0)), .rocks)
        XCTAssertEqual(m.terrain(at: Position(x: 2, y: 1)), .water)
    }

    /// A house on an upper layer blocks the grass under it, whichever order
    /// the layers come in; an empty type means the layer has nothing there.
    func testMostRestrictiveLayerWins() throws {
        let ground = Array(repeating: "OPEN", count: 6)
        let objects = ["", "", "", "", "", "NO_PASS"]
        for layers in [[ground, objects], [objects, ground]] {
            let m = try map(layers)
            XCTAssertEqual(m.terrain(at: Position(x: 2, y: 1)), .rocks)
            XCTAssertEqual(m.terrain(at: Position(x: 2, y: 0)), .open)
        }
    }

    func testLayersWithoutTypesAreIgnored() throws {
        let m = try map([nil, Array(repeating: "OPEN", count: 6)])
        XCTAssertEqual(m.terrain(at: Position(x: 0, y: 0)), .open)
    }

    func testInvalidTiledMapsAreRejected() {
        let open = Array(repeating: "OPEN", count: 6)
        let cases: [(String, () throws -> Any)] = [
            ("unknown type", { try self.map([["OPEN", "LAVA", "OPEN", "OPEN", "OPEN", "OPEN"]]) }),
            ("cell with no type", { try self.map([["OPEN", "", "OPEN", "OPEN", "OPEN", "OPEN"]]) }),
            ("no types at all", { try self.map([nil]) }),
            ("wrong type count", { try self.map([Array(open.dropLast())]) }),
            ("no tile layers", { try self.map([]) }),
            ("wrong tile count", {
                try self.parse(self.tiledJSON(layers: [([1, 2], open)]))
            }),
            ("infinite map", { try self.parse(self.tiledJSON(layers: [(nil, open)], infinite: true)) }),
            ("not JSON", { try self.parse(Data("ascii?".utf8)) }),
            ("missing external tileset", {
                try self.parse(self.tiledJSON(layers: [(nil, open)],
                                              tilesets: [["firstgid": 1, "source": "gone.tsj"]]))
            }),
            ("supply on blocked ground", {
                try self.map([["OPEN", "OPEN", "NO_PASS", "OPEN", "OPEN", "OPEN"]])
            }),
        ]
        for (name, build) in cases {
            XCTAssertThrowsError(try build(), name)
        }
    }

    // MARK: - Tile layers

    func testTilesetsLoadInlineAndExternal() throws {
        var inline = tileset(name: "inline")
        inline["firstgid"] = 5
        let tiled = try parse(
            tiledJSON(layers: [([1, 4, 5, 8, 0, 0], nil)],
                      tilesets: [inline, ["firstgid": 1, "source": "ext.tsj"]]),
            external: ["ext.tsj": tileset(name: "external")])

        XCTAssertEqual(tiled.tilesets.map(\.name), ["external", "inline"], "Sorted by first gid")
        let layer = tiled.layers[0]
        XCTAssertEqual(tiled.tile(in: layer, at: Position(x: 0, y: 0))?.tileset.name, "external")
        XCTAssertEqual(tiled.tile(in: layer, at: Position(x: 1, y: 0))?.localID, 3)
        XCTAssertEqual(tiled.tile(in: layer, at: Position(x: 2, y: 0))?.tileset.name, "inline")
        XCTAssertEqual(tiled.tile(in: layer, at: Position(x: 2, y: 0))?.localID, 0)
        XCTAssertEqual(tiled.tile(in: layer, at: Position(x: 0, y: 1))?.localID, 3)
        XCTAssertNil(tiled.tile(in: layer, at: Position(x: 1, y: 1)), "gid 0 is an empty cell")
        XCTAssertNil(tiled.tile(in: layer, at: Position(x: 3, y: 0)), "off the map")
    }

    func testFlipFlagsAreSplitFromTheGid() throws {
        var set = tileset()
        set["firstgid"] = 1
        let flippedH: UInt32 = 0x8000_0000 | 2
        let flippedVD: UInt32 = 0x4000_0000 | 0x2000_0000 | 3
        let tiled = try parse(tiledJSON(layers: [([flippedH, flippedVD, 1, 1, 1, 1], nil)], tilesets: [set]))
        let h = try XCTUnwrap(tiled.tile(in: tiled.layers[0], at: Position(x: 0, y: 0)))
        XCTAssertEqual(h.localID, 1)
        XCTAssertTrue(h.flippedHorizontally)
        XCTAssertFalse(h.flippedVertically || h.flippedDiagonally)
        let vd = try XCTUnwrap(tiled.tile(in: tiled.layers[0], at: Position(x: 1, y: 0)))
        XCTAssertEqual(vd.localID, 2)
        XCTAssertTrue(vd.flippedVertically && vd.flippedDiagonally)
        XCTAssertFalse(vd.flippedHorizontally)
    }

    func testGidsBeyondTheLastTilesetAreEmpty() throws {
        var set = tileset(count: 4)
        set["firstgid"] = 1
        let tiled = try parse(tiledJSON(layers: [([5, 0, 0, 0, 0, 0], nil)], tilesets: [set]))
        XCTAssertNil(tiled.tile(in: tiled.layers[0], at: Position(x: 0, y: 0)))
    }

    func testPixelRectCountsMarginAndSpacing() throws {
        var set = tileset(columns: 3, count: 6, margin: 1, spacing: 2)
        set["firstgid"] = 1
        let tiled = try parse(tiledJSON(layers: [(nil, nil)], tilesets: [set]))
        let rect = tiled.tilesets[0].pixelRect(of: 4)   // column 1, row 1
        XCTAssertEqual(rect.x, 1 + 66)
        XCTAssertEqual(rect.y, 1 + 66)
        XCTAssertEqual(rect.width, 64)
        XCTAssertEqual(rect.height, 64)
    }

    // MARK: - Twin Lakes

    func testTwinLakesLoads() throws {
        let (m, tiled) = try Maps.twinLakes()
        XCTAssertEqual(m.width, 12)
        XCTAssertEqual(m.height, 18)
        XCTAssertEqual(tiled.tileWidth, 92)
        XCTAssertEqual(tiled.tileHeight, 92)
        XCTAssertEqual(tiled.layers.map(\.name), ["Background", "Ground", "Objects"])
        XCTAssertEqual(m.supplyTiles[.ai], Position(x: 9, y: 0))
        XCTAssertEqual(m.supplyTiles[.player], Position(x: 2, y: 17))

        // Lakes, villages, rocks and forest, exactly as the Ground layer types them.
        let blocked: Set<Position> = [
            Position(x: 3, y: 1), Position(x: 4, y: 1),
            Position(x: 3, y: 2), Position(x: 4, y: 2),
            Position(x: 0, y: 3), Position(x: 1, y: 3), Position(x: 8, y: 3), Position(x: 11, y: 3),
            Position(x: 0, y: 4), Position(x: 1, y: 4), Position(x: 2, y: 4), Position(x: 3, y: 4),
            Position(x: 4, y: 4), Position(x: 5, y: 4), Position(x: 8, y: 4), Position(x: 11, y: 4),
            Position(x: 0, y: 5), Position(x: 3, y: 5), Position(x: 4, y: 5), Position(x: 8, y: 5),
            Position(x: 11, y: 5),
            Position(x: 2, y: 6), Position(x: 3, y: 6), Position(x: 4, y: 6), Position(x: 8, y: 6),
            Position(x: 11, y: 7),
            Position(x: 4, y: 9), Position(x: 6, y: 9),
            Position(x: 8, y: 10), Position(x: 9, y: 10), Position(x: 10, y: 10),
            Position(x: 0, y: 11), Position(x: 8, y: 11), Position(x: 9, y: 11), Position(x: 10, y: 11),
            Position(x: 0, y: 12), Position(x: 3, y: 12), Position(x: 6, y: 12), Position(x: 7, y: 12),
            Position(x: 8, y: 12), Position(x: 9, y: 12), Position(x: 10, y: 12),
            Position(x: 6, y: 13), Position(x: 7, y: 13), Position(x: 8, y: 13), Position(x: 9, y: 13),
            Position(x: 10, y: 13),
            Position(x: 0, y: 14), Position(x: 10, y: 14),
            Position(x: 0, y: 15), Position(x: 8, y: 15),
            Position(x: 8, y: 16),
        ]
        for y in 0..<m.height {
            for x in 0..<m.width {
                let p = Position(x: x, y: y)
                XCTAssertEqual(m.terrain(at: p), blocked.contains(p) ? .rocks : .open, "at \(p)")
            }
        }
        XCTAssertNoThrow(try GameState.newGame(map: m))
    }

    /// Every cell of the map has art under it: the background layer covers it all.
    func testTwinLakesHasArtEverywhere() throws {
        let (m, tiled) = try Maps.twinLakes()
        let background = try XCTUnwrap(tiled.layers.first)
        for y in 0..<m.height {
            for x in 0..<m.width {
                XCTAssertNotNil(tiled.tile(in: background, at: Position(x: x, y: y)), "at (\(x), \(y))")
            }
        }
    }

    /// Red's corner is Blue's turned through 180°, depot and spawns alike, so
    /// each army stands the same way round its own depot.
    func testTwinLakesCornersMirrorEachOther() throws {
        let m = try Maps.twinLakes().map
        func mirrored(_ p: Position) -> Position { Position(x: 11 - p.x, y: 17 - p.y) }
        XCTAssertEqual(mirrored(m.supplyTiles[.ai]!), m.supplyTiles[.player])
        XCTAssertEqual(m.spawnTiles[.ai]!.map(mirrored), m.spawnTiles[.player])

        let supplies = Set(m.supplyTiles.values)
        for spawn in m.spawnTiles.values.joined() {
            XCTAssertFalse(supplies.contains(spawn), "\(spawn) is a supply tile")
        }
    }

    /// Every open tile can be reached from Blue's corner, so no obstacle walls
    /// off a depot or a pocket of the field.
    func testTwinLakesHasNoSealedPockets() throws {
        let m = try Maps.twinLakes().map
        var seen: Set<Position> = [m.spawnTiles[.player]![0]]
        var frontier = Array(seen)
        while let p = frontier.popLast() {
            for n in p.orthogonalNeighbors where !seen.contains(n) && m.terrain(at: n)?.isPassable == true {
                seen.insert(n)
                frontier.append(n)
            }
        }
        let passable = (0..<m.height).flatMap { y in (0..<m.width).map { Position(x: $0, y: y) } }
            .filter { m.terrain(at: $0)?.isPassable == true }
        XCTAssertEqual(seen, Set(passable))
    }
}
