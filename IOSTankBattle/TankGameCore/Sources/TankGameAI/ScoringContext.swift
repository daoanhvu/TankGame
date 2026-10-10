import TankGameCore

/// The maps a scoring pass needs, which are the same for all few hundred
/// candidates and expensive enough that building them per candidate is the one
/// performance mistake worth avoiding here.
///
/// Built once per decision by `GreedyAI` and handed to the evaluator.
public struct ScoringContext: Sendable {

    /// The side being scored for.
    public let side: Side
    /// What the enemy can shoot next turn.
    public let threat: ThreatMap
    /// Driving distance to the nearest living enemy.
    public let toEnemy: DistanceField
    /// Driving distance to this side's own supply tile, if it has one.
    public let toDepot: DistanceField?

    public init(for side: Side, in state: GameState) {
        self.side = side
        self.threat = ThreatMap(threatTo: side, in: state)
        self.toEnemy = DistanceField(to: state.aliveTanks(of: side.opponent).map(\.position),
                                     movingAs: side, in: state)
        self.toDepot = state.map.supplyTiles[side].map {
            DistanceField(to: [$0], movingAs: side, in: state)
        }
    }
}
