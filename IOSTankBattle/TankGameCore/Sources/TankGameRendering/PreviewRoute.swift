import TankGameCore

/// Works out the tiles a previewed tank still has to drive when the player
/// re-points its move.
///
/// Both routes start at the tank's real tile, so whatever they share at the
/// front is drive that does not need redoing. The tank reverses to the tile
/// where the two routes diverge, then drives out along the new one — which
/// means extending a route simply carries on forward.
///
/// Pure and separate from the scene because it is all index arithmetic, and
/// index arithmetic deserves tests.
enum PreviewRoute {

    /// The tiles to visit, in order, excluding the one the tank is standing on.
    ///
    /// Both arguments are full routes starting at the tank's real tile; a tank
    /// that has not moved has a route of just that one tile.
    static func tiles(from current: [Position], to target: [Position]) -> [Position] {
        guard !current.isEmpty, !target.isEmpty else { return target }

        // At least 1: both routes begin on the tank's own tile.
        let shared = max(1, zip(current, target).prefix { $0 == $1 }.count)
        let backtrack = current[(shared - 1)..<(current.count - 1)].reversed()
        let outbound = target[shared...]
        return Array(backtrack) + Array(outbound)
    }
}
