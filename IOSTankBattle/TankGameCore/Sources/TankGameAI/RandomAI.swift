import TankGameCore

/// Plays a uniformly random legal action.
///
/// Not a difficulty setting — it is the control group. A scoring change that
/// cannot beat this convincingly is not an improvement, and it is the cheapest
/// way to prove `ActionGenerator` only ever offers legal actions.
public struct RandomAI: TankAI {

    public let name = "Random"
    /// Chance of passing even when actions are available, so random play still
    /// exercises the pass path.
    public var passChance: Double
    private let seed: UInt64

    public init(seed: UInt64 = 0xD1CE, passChance: Double = 0.05) {
        self.seed = seed
        self.passChance = passChance
    }

    public func chooseAction(in state: GameState) -> Action {
        var rng = SeededGenerator(seed: seed &+ UInt64(state.round) &* 31
                                     &+ (state.currentSide == .ai ? 7 : 0))
        guard Double.random(in: 0...1, using: &rng) >= passChance,
              let candidate = ActionGenerator.candidates(in: state, includePass: false)
                  .randomElement(using: &rng)
        else { return .pass }
        return candidate.action
    }
}
