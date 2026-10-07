/// One turn = exactly one Action by the side to move.
public enum Action: Hashable, Codable, Sendable {
    /// Do nothing this turn.
    case pass
    /// Select one tank, optionally move it, optionally fire.
    case command(TankCommand)
}

/// What a single tank does in its turn.
/// - Stay in place: `destination == tank.position`.
/// - Move without firing: `targetID == nil`.
/// Legality (reachability, range, ammo, ...) is checked by the rules (tasks 2-6),
/// not here, so the AI can generate candidates freely and filter them.
public struct TankCommand: Hashable, Codable, Sendable {
    public let tankID: TankID
    public let destination: Position
    public let targetID: TankID?

    public init(tankID: TankID, destination: Position, targetID: TankID? = nil) {
        self.tankID = tankID
        self.destination = destination
        self.targetID = targetID
    }
}
