import Foundation

/// A map made in the Tiled editor (`.tmj`), as data: its tile layers and the
/// tilesets they draw from.
///
/// The rules never look at it. `GameMap(tiled:supplyTiles:spawnTiles:)` reads
/// the gameplay out of it (the per-cell `types`), and the renderer draws its
/// layers; keeping both on one parsed value means the board can never show a
/// different map from the one being played.
public struct TiledMap: Equatable, Sendable {

    public struct Layer: Equatable, Sendable {
        public let name: String
        /// Row-major global tile IDs, flip flags included; 0 = no tile here.
        public let gids: [UInt32]
        /// Row-major gameplay types (`OPEN`, `NO_PASS`, ...), or nil if the
        /// layer has none. An empty string means "no opinion".
        public let types: [String]?
        public let isVisible: Bool
        public let opacity: Double
    }

    public struct Tileset: Equatable, Sendable {
        /// The global ID of this set's first tile.
        public let firstGID: Int
        public let name: String
        public let columns: Int
        public let tileCount: Int
        public let tileWidth: Int
        public let tileHeight: Int
        public let margin: Int
        public let spacing: Int
        public let imageWidth: Int
        public let imageHeight: Int

        /// Where tile `localID` sits in the tileset image, in pixels with a
        /// TOP-LEFT origin, as Tiled counts them.
        public func pixelRect(of localID: Int) -> (x: Int, y: Int, width: Int, height: Int) {
            let column = localID % max(columns, 1)
            let row = localID / max(columns, 1)
            return (margin + column * (tileWidth + spacing),
                    margin + row * (tileHeight + spacing),
                    tileWidth, tileHeight)
        }
    }

    /// One cell's tile: which set, which tile in it, and how it is flipped.
    public struct TileRef: Equatable, Sendable {
        public let tileset: Tileset
        public let localID: Int
        public let flippedHorizontally: Bool
        public let flippedVertically: Bool
        /// Tiled's anti-diagonal flip: swap x and y, applied before the other two.
        public let flippedDiagonally: Bool
    }

    public let width: Int
    public let height: Int
    public let tileWidth: Int
    public let tileHeight: Int
    /// Tile layers only, bottom first, in the order Tiled draws them.
    public let layers: [Layer]
    /// Sorted by `firstGID`.
    public let tilesets: [Tileset]

    /// - Parameter externalTileset: the contents of a tileset file the map
    ///   refers to by `source` (a `.tsj`). Only called for external sets.
    public init(json data: Data, externalTileset: (String) throws -> Data) throws {
        let file: TiledFile
        do {
            file = try JSONDecoder().decode(TiledFile.self, from: data)
        } catch {
            throw GameModelError.invalidMap("Not a Tiled map: \(error)")
        }
        guard file.infinite != true else {
            throw GameModelError.invalidMap("Infinite Tiled maps are not supported")
        }
        guard file.width > 0, file.height > 0 else {
            throw GameModelError.invalidMap("Tiled map must be at least 1x1")
        }

        let cellCount = file.width * file.height
        var layers: [Layer] = []
        for layer in file.layers where layer.type == "tilelayer" {
            let gids = layer.data ?? Array(repeating: 0, count: cellCount)
            guard gids.count == cellCount else {
                throw GameModelError.invalidMap(
                    "Layer '\(layer.name)' has \(gids.count) tiles, expected \(cellCount)")
            }
            if let types = layer.types, types.count != cellCount {
                throw GameModelError.invalidMap(
                    "Layer '\(layer.name)' has \(types.count) types, expected \(cellCount)")
            }
            layers.append(Layer(name: layer.name, gids: gids, types: layer.types,
                                isVisible: layer.visible ?? true, opacity: layer.opacity ?? 1))
        }

        var tilesets: [Tileset] = []
        for reference in file.tilesets ?? [] {
            let body: TiledFile.TilesetBody
            if let source = reference.source {
                do {
                    body = try JSONDecoder().decode(TiledFile.TilesetBody.self, from: try externalTileset(source))
                } catch {
                    throw GameModelError.invalidMap("Tileset '\(source)' could not be read: \(error)")
                }
            } else if let inline = reference.inline {
                body = inline
            } else {
                throw GameModelError.invalidMap("Tileset at gid \(reference.firstgid) has no source or image")
            }
            tilesets.append(Tileset(firstGID: reference.firstgid, name: body.name, columns: body.columns,
                                    tileCount: body.tilecount, tileWidth: body.tilewidth,
                                    tileHeight: body.tileheight, margin: body.margin ?? 0,
                                    spacing: body.spacing ?? 0, imageWidth: body.imagewidth,
                                    imageHeight: body.imageheight))
        }

        self.width = file.width
        self.height = file.height
        self.tileWidth = file.tilewidth
        self.tileHeight = file.tileheight
        self.layers = layers
        self.tilesets = tilesets.sorted { $0.firstGID < $1.firstGID }
    }

    // MARK: - Lookup

    private static let flipHorizontal: UInt32 = 0x8000_0000
    private static let flipVertical: UInt32 = 0x4000_0000
    private static let flipDiagonal: UInt32 = 0x2000_0000
    /// Also masks Tiled's hexagonal-rotation bit, which an orthogonal map never sets.
    private static let flagMask: UInt32 = 0xF000_0000

    /// The tile a layer places at `p`, or nil for an empty cell, a cell off
    /// the map, or a gid no tileset owns.
    public func tile(in layer: Layer, at p: Position) -> TileRef? {
        guard p.x >= 0, p.x < width, p.y >= 0, p.y < height else { return nil }
        let raw = layer.gids[p.y * width + p.x]
        let gid = Int(raw & ~Self.flagMask)
        guard gid != 0,
              let tileset = tilesets.last(where: { $0.firstGID <= gid }),
              gid - tileset.firstGID < tileset.tileCount else { return nil }
        return TileRef(tileset: tileset, localID: gid - tileset.firstGID,
                       flippedHorizontally: raw & Self.flipHorizontal != 0,
                       flippedVertically: raw & Self.flipVertical != 0,
                       flippedDiagonally: raw & Self.flipDiagonal != 0)
    }
}

// MARK: - Gameplay

extension GameMap {
    /// The gameplay half of a Tiled map. Every tile layer may carry a `types`
    /// array naming what each cell is:
    ///
    ///     OPEN                    open ground, tanks drive through it
    ///     NO_PASS (NO-PASSABLE)   blocked: houses, rocks, forest
    ///     WATER                   blocked: river or lake
    ///     ""                      this layer says nothing about the cell
    ///
    /// The layers are stacked, so a house in an object layer blocks the grass
    /// in the ground layer under it: the most restrictive type wins. A cell no
    /// layer gives a type to is an error rather than a guess.
    ///
    /// The format has no supply or spawn markers yet, so those come from the
    /// caller. Spawns are used in the order given, for both sides (unlike the
    /// ASCII format, which reverses the AI's to mirror the player's).
    public init(tiled: TiledMap,
                supplyTiles: [Side: Position],
                spawnTiles: [Side: [Position]]) throws {
        let layers = tiled.layers.filter { $0.types != nil }
        guard !layers.isEmpty else {
            throw GameModelError.invalidMap("No layer of the Tiled map has tile types")
        }

        var cells: [Terrain?] = Array(repeating: nil, count: tiled.width * tiled.height)
        for layer in layers {
            for (index, name) in (layer.types ?? []).enumerated() where !name.isEmpty {
                let position = Position(x: index % tiled.width, y: index / tiled.width)
                guard let terrain = Self.tiledTerrain[name] else {
                    throw GameModelError.invalidMap(
                        "Unknown tile type '\(name)' at \(position) in layer '\(layer.name)'")
                }
                cells[index] = Self.moreRestrictive(cells[index], terrain)
            }
        }

        let tiles = try cells.enumerated().map { index, terrain -> Terrain in
            guard let terrain else {
                let position = Position(x: index % tiled.width, y: index / tiled.width)
                throw GameModelError.invalidMap("No layer gives a type to the cell at \(position)")
            }
            return terrain
        }

        try self.init(width: tiled.width, height: tiled.height, tiles: tiles,
                      supplyTiles: supplyTiles, spawnTiles: spawnTiles)
    }

    /// The editor's type names. `NO-PASSABLE` is how its built-in tileset spells
    /// `NO_PASS`. Blocked ground maps to rocks: the rules treat every impassable
    /// terrain alike, and the tile art shows what is really there.
    private static let tiledTerrain: [String: Terrain] = [
        "OPEN": .open,
        "NO_PASS": .rocks,
        "NO-PASSABLE": .rocks,
        "WATER": .water,
    ]

    private static func moreRestrictive(_ current: Terrain?, _ new: Terrain) -> Terrain {
        guard let current else { return new }
        return current.isPassable && !new.isPassable ? new : current
    }
}

// MARK: - File format

/// The fields of a Tiled map the game reads; everything else is ignored.
private struct TiledFile: Decodable {
    let width: Int
    let height: Int
    let tilewidth: Int
    let tileheight: Int
    let infinite: Bool?
    let layers: [Layer]
    let tilesets: [TilesetReference]?

    struct Layer: Decodable {
        let name: String
        let type: String
        let data: [UInt32]?
        let types: [String]?
        let visible: Bool?
        let opacity: Double?
    }

    /// Either `{firstgid, source}` pointing at a `.tsj`, or the set inline.
    struct TilesetReference: Decodable {
        let firstgid: Int
        let source: String?
        let inline: TilesetBody?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            firstgid = try container.decode(Int.self, forKey: .firstgid)
            source = try container.decodeIfPresent(String.self, forKey: .source)
            inline = source == nil ? try TilesetBody(from: decoder) : nil
        }

        enum CodingKeys: String, CodingKey { case firstgid, source }
    }

    struct TilesetBody: Decodable {
        let name: String
        let columns: Int
        let tilecount: Int
        let tilewidth: Int
        let tileheight: Int
        let margin: Int?
        let spacing: Int?
        let imagewidth: Int
        let imageheight: Int
    }
}
