import TankGameCore

/// Move cost from every tile on the map to the nearest of a set of targets,
/// for a tank of one side.
///
/// The reason this exists rather than a Manhattan distance: tanks drive
/// orthogonally around rocks and water, so on a map with a river down the
/// middle "closer in a straight line" and "closer to drive" are different
/// things — and the straight line is the wrong one. Measured as the crow
/// flies, the tiles on the near bank all look equally far from an enemy on the
/// far bank, the approach term reads every detour as zero progress, and a
/// greedy brain parks its whole army on the bank for the rest of the match.
///
/// Flooded once per decision (multi-source Dijkstra, same terrain costs and
/// entry rules as `Rules.movementCosts`) and shared by every candidate.
/// Tanks are ignored on purpose: they will have moved by the time this matters,
/// and a field that changed whenever somebody parked in a gap would make the
/// approach term jitter.
public struct DistanceField: Sendable, Equatable {

    private let costs: [Position: Int]

    /// - Parameters:
    ///   - targets: the tiles to measure to; the nearest one wins.
    ///   - side: whose tank is doing the driving, which decides whether the
    ///     enemy supply tile is a hole in the map or a shortcut through it.
    public init(to targets: [Position], movingAs side: Side, in state: GameState) {
        var costs: [Position: Int] = [:]
        var frontier: [Position: Int] = [:]
        for target in targets where state.map.contains(target) {
            // Flood from every target, but only report a cost for tiles this
            // side could actually stand on: an enemy sitting on its own supply
            // tile still radiates a gradient, yet the tile itself is a hole in
            // our map, not a destination.
            frontier[target] = 0
            if state.map.canEnter(target, side: side) { costs[target] = 0 }
        }
        var settled: Set<Position> = []

        while let (tile, cost) = frontier.min(by: { $0.value < $1.value }) {
            frontier[tile] = nil
            guard settled.insert(tile).inserted else { continue }

            for next in tile.orthogonalNeighbors {
                guard !settled.contains(next),
                      state.map.canEnter(next, side: side),
                      let step = state.map.terrain(at: next)?.moveCost
                else { continue }

                let total = cost + step
                if let known = costs[next], known <= total { continue }
                costs[next] = total
                frontier[next] = total
            }
        }
        self.costs = costs
    }

    /// Move points needed to get from `tile` to the nearest target, or nil if
    /// no route exists (a walled-off pocket, or a tile this side may not enter).
    public func cost(at tile: Position) -> Int? {
        costs[tile]
    }

    /// Ground gained by driving from `origin` to `destination`: positive for
    /// progress, negative for backing off, 0 when either end is cut off and
    /// there is no gradient to follow.
    public func progress(from origin: Position, to destination: Position) -> Int {
        guard let before = cost(at: origin), let after = cost(at: destination) else { return 0 }
        return before - after
    }
}
