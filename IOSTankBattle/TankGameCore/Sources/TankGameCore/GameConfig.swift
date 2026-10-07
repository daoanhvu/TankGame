import Foundation

/// All tunable numbers for a match. Loadable from JSON for easy balancing.
public struct GameConfig: Codable, Equatable, Sendable {
    public var tankStats: [TankKind: TankStats]
    /// Army lineup, identical for both sides. Order matters: tanks are
    /// assigned to spawn tiles in this order (see `GameState.newGame`).
    public var army: [TankKind]
    /// One round = one player action + one AI action.
    public var maxRounds: Int
    /// Which side acts first in round 1.
    public var firstSide: Side

    public init(tankStats: [TankKind: TankStats], army: [TankKind],
                maxRounds: Int, firstSide: Side) {
        self.tankStats = tankStats
        self.army = army
        self.maxRounds = maxRounds
        self.firstSide = firstSide
    }

    public static let phase1Default = GameConfig(
        tankStats: [
            .light:     TankStats(movePoints: 5, minRange: 1, maxRange: 1, maxHP: 6,  damage: 3, maxAmmo: 6),
            .medium:    TankStats(movePoints: 3, minRange: 1, maxRange: 2, maxHP: 10, damage: 4, maxAmmo: 5),
            .artillery: TankStats(movePoints: 2, minRange: 2, maxRange: 4, maxHP: 7,  damage: 5, maxAmmo: 3),
        ],
        army: [.light, .light, .medium, .medium, .artillery],
        maxRounds: 40,
        firstSide: .player
    )

    /// Stats lookup. Crashes on a missing kind because that is a config bug,
    /// which `validate()` is meant to catch at load time.
    public func stats(for kind: TankKind) -> TankStats {
        guard let s = tankStats[kind] else {
            preconditionFailure("No stats configured for tank kind \(kind)")
        }
        return s
    }

    public static func load(fromJSON data: Data) throws -> GameConfig {
        let config = try JSONDecoder().decode(GameConfig.self, from: data)
        try config.validate()
        return config
    }

    public func validate() throws {
        guard !army.isEmpty else { throw GameModelError.invalidConfig("Army is empty") }
        guard maxRounds > 0 else { throw GameModelError.invalidConfig("maxRounds must be > 0") }
        for kind in Set(army) {
            guard let s = tankStats[kind] else {
                throw GameModelError.invalidConfig("Missing stats for \(kind)")
            }
            guard s.movePoints >= 0, s.maxHP > 0, s.damage > 0, s.maxAmmo >= 0,
                  s.minRange >= 1, s.maxRange >= s.minRange else {
                throw GameModelError.invalidConfig("Invalid stats for \(kind): \(s)")
            }
        }
    }
}
