import TankGameCore

/// Which enemy guns can reach each tile next turn.
///
/// Built by asking, for every living enemy with ammo, where it could drive and
/// what it could shoot from there. Two readings come out of that, and the
/// difference between them matters more than it looks:
///
/// - `strongestShot(at:)` — the biggest single hit the tile can take. Since a
///   side gets exactly ONE action per turn, this is the real damage a tank
///   standing there risks, and it is what the evaluator prices.
/// - `damage(at:)` — every gun that bears, added up. An upper bound no enemy
///   can actually collect, useful as a "how contested is this ground" signal
///   (a future minimax can weigh crossfire properly); priced too heavily it
///   just makes a one-ply brain refuse to approach a group at all.
///
/// Built once per decision and shared by every candidate; building it per
/// candidate would be the expensive mistake here.
public struct ThreatMap: Sendable, Equatable {

    /// The side being threatened.
    public let side: Side
    private let damageByTile: [Position: Int]
    private let strongestByTile: [Position: Int]

    /// - Parameter side: the side under threat. Enemies are `side.opponent`.
    public init(threatTo side: Side, in state: GameState) {
        self.side = side
        var total: [Position: Int] = [:]
        var strongest: [Position: Int] = [:]

        for enemy in state.aliveTanks(of: side.opponent) where enemy.hasAmmo {
            let stats = state.stats(of: enemy)
            // Per enemy, collect the tiles it covers in a set first: it fires
            // once, so overlapping firing positions must not stack its damage.
            var covered: Set<Position> = []
            for firingTile in Rules.reachableTiles(for: enemy, in: state).keys {
                for tile in Self.tiles(inRangeOf: stats, from: firingTile, map: state.map) {
                    covered.insert(tile)
                }
            }
            for tile in covered {
                total[tile, default: 0] += stats.damage
                strongest[tile] = max(strongest[tile] ?? 0, stats.damage)
            }
        }
        self.damageByTile = total
        self.strongestByTile = strongest
    }

    /// Every enemy gun that bears on `tile`, added up. 0 for safe tiles.
    /// See the note above before scoring with this rather than
    /// `strongestShot(at:)`.
    public func damage(at tile: Position) -> Int {
        damageByTile[tile] ?? 0
    }

    /// The biggest single hit `tile` can take next turn, i.e. what one enemy
    /// action can actually do. 0 for safe tiles.
    public func strongestShot(at tile: Position) -> Int {
        strongestByTile[tile] ?? 0
    }

    /// True if one enemy action could finish this tank off where it stands.
    /// Worth its own term in the score: losing a tank is a step change, not
    /// one more point of damage.
    public func isLethal(for tank: Tank, at tile: Position) -> Bool {
        strongestShot(at: tile) >= tank.hp
    }

    /// Tiles inside a weapon's range band from a firing tile, clipped to the
    /// map. Terrain never blocks shots in phase 1, so this is pure geometry.
    private static func tiles(inRangeOf stats: TankStats,
                              from origin: Position,
                              map: GameMap) -> [Position] {
        var tiles: [Position] = []
        for dy in -stats.maxRange...stats.maxRange {
            let remaining = stats.maxRange - abs(dy)
            for dx in -remaining...remaining {
                let distance = abs(dx) + abs(dy)
                guard stats.canReach(distance: distance) else { continue }
                let tile = Position(x: origin.x + dx, y: origin.y + dy)
                if map.contains(tile) { tiles.append(tile) }
            }
        }
        return tiles
    }
}
