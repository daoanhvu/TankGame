public enum GameResult: Hashable, Codable, Sendable {
    case win(Side, WinReason)
    case draw
}

public enum WinReason: String, Hashable, Codable, Sendable {
    /// Every enemy tank was destroyed.
    case annihilation
    /// Round limit reached; this side had more total remaining HP.
    case moreHPAtRoundLimit
}

public enum GameStatus: Hashable, Codable, Sendable {
    case ongoing
    case finished(GameResult)
}

/// The complete, copyable snapshot of a match.
/// A value type on purpose: the AI copies it to simulate futures,
/// and the UI just renders whatever state it is given.
public struct GameState: Equatable, Codable, Sendable {
    public let config: GameConfig
    public let map: GameMap
    /// All tanks, including destroyed ones. A tank's `id` is its index here.
    public internal(set) var tanks: [Tank]
    public internal(set) var currentSide: Side
    /// 1-based. A round ends after both sides have acted once.
    public internal(set) var round: Int
    public internal(set) var status: GameStatus

    public init(config: GameConfig, map: GameMap, tanks: [Tank],
                currentSide: Side, round: Int, status: GameStatus) {
        self.config = config
        self.map = map
        self.tanks = tanks
        self.currentSide = currentSide
        self.round = round
        self.status = status
    }

    /// Sets up a fresh match: both sides get `config.army`, full HP and ammo,
    /// placed on the map's spawn tiles in order.
    public static func newGame(config: GameConfig = .phase1Default,
                               map: GameMap) throws -> GameState {
        try config.validate()
        var tanks: [Tank] = []
        for side in Side.allCases {
            let spawns = map.spawnTiles[side] ?? []
            guard spawns.count == config.army.count else {
                throw GameModelError.invalidMap(
                    "\(side) has \(spawns.count) spawn tiles but the army has \(config.army.count) tanks")
            }
            for (kind, spawn) in zip(config.army, spawns) {
                let s = config.stats(for: kind)
                tanks.append(Tank(id: tanks.count, side: side, kind: kind,
                                  position: spawn, hp: s.maxHP, ammo: s.maxAmmo))
            }
        }
        return GameState(config: config, map: map, tanks: tanks,
                         currentSide: config.firstSide, round: 1, status: .ongoing)
    }

    // MARK: - Convenience queries

    public func tank(_ id: TankID) -> Tank? {
        tanks.indices.contains(id) ? tanks[id] : nil
    }

    /// The living tank standing on `p`, if any.
    public func tank(at p: Position) -> Tank? {
        tanks.first { $0.isAlive && $0.position == p }
    }

    public func aliveTanks(of side: Side) -> [Tank] {
        tanks.filter { $0.side == side && $0.isAlive }
    }

    public func totalHP(of side: Side) -> Int {
        aliveTanks(of: side).reduce(0) { $0 + $1.hp }
    }

    public func stats(of tank: Tank) -> TankStats {
        config.stats(for: tank.kind)
    }

    public var isOver: Bool {
        if case .finished = status { return true }
        return false
    }
}
