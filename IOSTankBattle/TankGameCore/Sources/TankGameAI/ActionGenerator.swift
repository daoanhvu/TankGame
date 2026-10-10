import TankGameCore

/// Every legal action one side could take this turn.
///
/// The rules deliberately do not check legality in the model types, so this is
/// where "what could I do?" lives: for each living tank, every tile it may stop
/// on, and from each of those tiles every enemy it could hit, plus the option
/// of holding fire. Each candidate carries the pieces the evaluator would
/// otherwise have to recompute.
///
/// Branching on the phase-1 map is small — 5 tanks x ~20 tiles x ~3 shooting
/// options is a few hundred candidates — so the generator is exhaustive rather
/// than pruned. A deeper search can filter this list instead of replacing it.
public enum ActionGenerator {

    /// One thing a side could do, with the context needed to score it.
    public struct Candidate: Equatable, Sendable {
        public let action: Action
        /// The acting tank, as it stands BEFORE the action. Nil for `.pass`.
        public let tank: Tank?
        /// Where the tank would end up (its own tile if it holds position).
        public let destination: Position?
        /// The tank as it would be after driving there, including the supply
        /// refill. Nil for `.pass`.
        public let movedTank: Tank?
        /// The enemy it would fire at, if any.
        public let target: Tank?

        public static let pass = Candidate(action: .pass, tank: nil, destination: nil,
                                           movedTank: nil, target: nil)
    }

    /// All candidates for `state.currentSide`, in a stable order.
    ///
    /// The order matters: the rules return reachable tiles in a dictionary, so
    /// without sorting, two runs on the same position could pick different
    /// equally-scored actions. Sorting here makes every AI built on top of it
    /// reproducible, which is what makes its bugs reproducible too.
    public static func candidates(in state: GameState, includePass: Bool = true) -> [Candidate] {
        guard !state.isOver else { return [] }
        let side = state.currentSide
        var result: [Candidate] = []

        for tank in state.aliveTanks(of: side).sorted(by: { $0.id < $1.id }) {
            let tiles = Rules.reachableTiles(for: tank, in: state).keys.sorted(by: readingOrder)

            for tile in tiles {
                let moved = Rules.tankAfterMove(tank, to: tile, in: state)
                let command = TankCommand(tankID: tank.id, destination: tile)
                result.append(Candidate(action: .command(command), tank: tank,
                                        destination: tile, movedTank: moved, target: nil))

                // Shooting is checked against the POST-move tank: a tank that
                // just rearmed on its supply tile may fire the same turn.
                let targets = Rules.attackableTargets(for: moved, in: state)
                    .sorted(by: { $0.id < $1.id })
                for target in targets {
                    let shot = TankCommand(tankID: tank.id, destination: tile, targetID: target.id)
                    result.append(Candidate(action: .command(shot), tank: tank,
                                            destination: tile, movedTank: moved, target: target))
                }
            }
        }

        if includePass { result.append(.pass) }
        return result
    }

    /// Top-left to bottom-right, so candidate order never depends on hashing.
    private static func readingOrder(_ a: Position, _ b: Position) -> Bool {
        (a.y, a.x) < (b.y, b.x)
    }
}
