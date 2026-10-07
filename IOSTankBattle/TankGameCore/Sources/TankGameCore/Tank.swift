public typealias TankID = Int

/// Dynamic per-tank state. Static stats live in `GameConfig`, looked up by `kind`.
public struct Tank: Identifiable, Hashable, Codable, Sendable {
    public let id: TankID
    public let side: Side
    public let kind: TankKind
    public var position: Position
    public var hp: Int
    public var ammo: Int

    public init(id: TankID, side: Side, kind: TankKind,
                position: Position, hp: Int, ammo: Int) {
        self.id = id
        self.side = side
        self.kind = kind
        self.position = position
        self.hp = hp
        self.ammo = ammo
    }

    /// Destroyed tanks stay in the array (simplifies IDs and animations)
    /// but are ignored by all rules.
    public var isAlive: Bool { hp > 0 }
    public var hasAmmo: Bool { ammo > 0 }
}
