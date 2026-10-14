@testable import TankGameRendering
import TankGameCore

/// The two confirming taps of the Tap-flow, named for readability. Both go
/// through `tapTile`, so a test using them exercises exactly what a finger does.
extension BoardInteraction {

    /// Taps Tile1 again: "just move" — move there and spend the tank's go, or
    /// hold position when Tile1 is the tank's own tile.
    @discardableResult
    mutating func tapTile1Again() -> [GameEvent] {
        guard let plan else { return [] }
        return tapTile(plan.destination)
    }

    /// Taps the aimed enemy a second time: move to Tile1, then fire.
    @discardableResult
    mutating func tapAimedEnemyAgain() -> [GameEvent] {
        guard let id = aimedTargetID, let target = state.tank(id) else { return [] }
        return tapTile(target.position)
    }
}
