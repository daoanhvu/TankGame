import TankGameCore

/// One decision-maker for one side.
///
/// This is the seam the rest of the game talks to, so every later brain
/// (2-ply minimax, difficulty levels, a learned policy) only has to implement
/// this one method. Nothing in this module holds mutable game state: an AI is
/// handed a `GameState` and hands back one `Action`, exactly like a human tap
/// flow would.
public protocol TankAI: Sendable {
    /// Shown in debug output and difficulty menus.
    var name: String { get }

    /// The action to take for `state.currentSide`.
    ///
    /// Implementations must return something legal for that side; `AIMatch`
    /// falls back to `.pass` if the rules reject it, so a buggy brain slows the
    /// game down instead of crashing it.
    func chooseAction(in state: GameState) -> Action
}
