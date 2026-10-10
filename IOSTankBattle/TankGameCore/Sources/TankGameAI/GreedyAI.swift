import TankGameCore

/// The phase-1 brain: enumerate every legal action, score each one on its
/// immediate merits, play the best.
///
/// One ply deep on purpose. It never asks what the player does next, so it can
/// be baited — walk a damaged tank just outside artillery range and it will
/// chase. That is an acceptable opponent for playtesting, and the point of
/// `TankAI` is that replacing it later touches nothing else.
///
/// Deterministic unless `weights.jitter` is set: the same position always
/// produces the same move, which is what makes a surprising move reproducible.
public struct GreedyAI: TankAI {

    public let name: String
    public var weights: AIWeights
    /// Base seed for `weights.jitter`. Mixed with the round and the side, so a
    /// given match plays out the same way every time while different turns
    /// still get different noise.
    public var seed: UInt64

    public init(weights: AIWeights = .standard, seed: UInt64 = 0x7A4B_1D2C, name: String = "Greedy") {
        self.weights = weights
        self.seed = seed
        self.name = name
    }

    public func chooseAction(in state: GameState) -> Action {
        best(in: state)?.candidate.action ?? .pass
    }

    /// The chosen action with its score — what a debug overlay or a balance
    /// test wants to look at.
    public func best(in state: GameState) -> ScoredCandidate? {
        rankedCandidates(in: state).first
    }

    /// Every candidate, best first. Ties keep generation order, which is
    /// sorted by tank then tile (see `ActionGenerator`), so the ranking is
    /// stable across runs.
    public func rankedCandidates(in state: GameState) -> [ScoredCandidate] {
        guard !state.isOver else { return [] }
        let evaluator = GreedyEvaluator(weights: weights)
        let context = ScoringContext(for: state.currentSide, in: state)
        var rng = SeededGenerator(seed: turnSeed(for: state))

        let scored = ActionGenerator.candidates(in: state).map { candidate in
            var score = evaluator.score(candidate, in: state, context: context)
            if weights.jitter > 0 {
                score.bias += Double.random(in: -weights.jitter...weights.jitter, using: &rng)
            }
            return ScoredCandidate(candidate: candidate, score: score)
        }
        // `enumerated` keeps the sort stable: Swift's sort is not.
        return scored.enumerated()
            .sorted { a, b in
                a.element.score.total == b.element.score.total
                    ? a.offset < b.offset
                    : a.element.score.total > b.element.score.total
            }
            .map(\.element)
    }

    private func turnSeed(for state: GameState) -> UInt64 {
        seed
            &+ UInt64(bitPattern: Int64(state.round)) &* 0x1_0000_0001
            &+ (state.currentSide == .player ? 0 : 0x5BF0_3635)
    }
}

/// A candidate with the score it was given.
public struct ScoredCandidate: Sendable {
    public let candidate: ActionGenerator.Candidate
    public let score: ActionScore

    /// One readable line per candidate, e.g.
    /// `tank 7 -> (4, 6) fire at 2 | 9.40 [damage +5.00 kill +6.00 ...]`.
    public var debugDescription: String {
        guard let tank = candidate.tank, let destination = candidate.destination else {
            return "pass | \(score.breakdown)"
        }
        let move = destination == tank.position ? "hold \(tank.position)" : "-> \(destination)"
        let shot = candidate.target.map { " fire at \($0.id)" } ?? ""
        return "tank \(tank.id) \(move)\(shot) | \(score.breakdown)"
    }
}
