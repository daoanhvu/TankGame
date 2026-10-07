import Foundation

/// Static map data: terrain grid, supply tiles and spawn tiles.
public struct GameMap: Equatable, Codable, Sendable {
    public let width: Int
    public let height: Int
    /// Row-major terrain, index = y * width + x.
    private let tiles: [Terrain]
    public let supplyTiles: [Side: Position]
    /// Spawn tiles per side, in the order tanks should be placed.
    public let spawnTiles: [Side: [Position]]

    public init(width: Int, height: Int, tiles: [Terrain],
                supplyTiles: [Side: Position], spawnTiles: [Side: [Position]]) throws {
        guard width > 0, height > 0 else {
            throw GameModelError.invalidMap("Map must be at least 1x1")
        }
        guard tiles.count == width * height else {
            throw GameModelError.invalidMap("Expected \(width * height) tiles, got \(tiles.count)")
        }
        self.width = width
        self.height = height
        self.tiles = tiles
        self.supplyTiles = supplyTiles
        self.spawnTiles = spawnTiles
        try validateSidesData()
    }

    // MARK: - Queries

    public func contains(_ p: Position) -> Bool {
        p.x >= 0 && p.x < width && p.y >= 0 && p.y < height
    }

    /// Terrain at `p`, or nil if out of bounds.
    public func terrain(at p: Position) -> Terrain? {
        guard contains(p) else { return nil }
        return tiles[p.y * width + p.x]
    }

    /// Which side owns the supply tile at `p`, if any.
    public func supplyOwner(at p: Position) -> Side? {
        supplyTiles.first { $0.value == p }?.key
    }

    /// Terrain-only entry rule for a tank of `side`: in bounds, passable
    /// terrain, and not the enemy's supply tile. Tank blocking is handled
    /// by the movement rules (task 2), since it depends on game state.
    public func canEnter(_ p: Position, side: Side) -> Bool {
        guard let t = terrain(at: p), t.isPassable else { return false }
        if let owner = supplyOwner(at: p), owner != side { return false }
        return true
    }

    // MARK: - Validation

    private func validateSidesData() throws {
        for side in Side.allCases {
            guard let supply = supplyTiles[side] else {
                throw GameModelError.invalidMap("Missing supply tile for \(side)")
            }
            guard terrain(at: supply)?.isPassable == true else {
                throw GameModelError.invalidMap("Supply tile for \(side) is not passable ground")
            }
            let spawns = spawnTiles[side] ?? []
            guard !spawns.isEmpty else {
                throw GameModelError.invalidMap("No spawn tiles for \(side)")
            }
            for s in spawns where terrain(at: s)?.isPassable != true {
                throw GameModelError.invalidMap("Spawn \(s) for \(side) is not passable ground")
            }
        }
        let allSpawns = spawnTiles.values.flatMap { $0 }
        guard Set(allSpawns).count == allSpawns.count else {
            throw GameModelError.invalidMap("Duplicate spawn tiles")
        }
    }
}

// MARK: - ASCII map format

extension GameMap {
    /// Builds a map from text, one line per row. Legend:
    ///
    ///     .  open ground        T  trees
    ///     R  rocks              W  water (river/lake)
    ///     S  player supply      s  AI supply
    ///     P  player spawn       a  AI spawn
    ///
    /// Supply and spawn tiles are open ground.
    ///
    /// Spawn order: player spawns are taken in reading order (top-left to
    /// bottom-right); AI spawns in REVERSE reading order. On a map that is
    /// 180°-rotationally symmetric, the same army slot then lands on
    /// mirrored tiles for both sides, which keeps starts fair.
    public init(ascii: String) throws {
        let rows = ascii
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let width = rows.first?.count, width > 0 else {
            throw GameModelError.invalidMap("Map text is empty")
        }

        var tiles: [Terrain] = []
        var supplies: [Side: Position] = [:]
        var playerSpawns: [Position] = []
        var aiSpawns: [Position] = []

        for (y, row) in rows.enumerated() {
            guard row.count == width else {
                throw GameModelError.invalidMap("Row \(y) has \(row.count) columns, expected \(width)")
            }
            for (x, ch) in row.enumerated() {
                let p = Position(x: x, y: y)
                switch ch {
                case ".": tiles.append(.open)
                case "T": tiles.append(.trees)
                case "R": tiles.append(.rocks)
                case "W": tiles.append(.water)
                case "S", "s":
                    let side: Side = (ch == "S") ? .player : .ai
                    guard supplies[side] == nil else {
                        throw GameModelError.invalidMap("More than one supply tile for \(side)")
                    }
                    supplies[side] = p
                    tiles.append(.open)
                case "P":
                    playerSpawns.append(p)
                    tiles.append(.open)
                case "a":
                    aiSpawns.append(p)
                    tiles.append(.open)
                default:
                    throw GameModelError.invalidMap("Unknown map character '\(ch)' at \(p)")
                }
            }
        }

        try self.init(
            width: width,
            height: rows.count,
            tiles: tiles,
            supplyTiles: supplies,
            spawnTiles: [.player: playerSpawns, .ai: Array(aiSpawns.reversed())]
        )
    }
}
