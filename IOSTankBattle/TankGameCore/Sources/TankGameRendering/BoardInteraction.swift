import TankGameCore
import TankGameAI

/// The tap-driven turn flow, as a pure state machine. It implements the
/// "Tap-flow" diagram in `docs/design.md`; everything is a tap, and only
/// Cancel and End Turn are buttons.
///
///     idle --tap own tank--> planning (Tile1 = its own tile)
///     planning --tap reachable tile--> planning (that tile is Tile1)
///     planning --tap Tile1 again--> committed: move there (or hold, if Tile1
///                                   is the tank's own tile)
///     planning --tap enemy with X--> aiming (damage preview shown)
///     aiming --tap the SAME enemy again--> committed: move to Tile1, then fire
///     aiming --tap Tile1 / another X / another tile--> as from planning
///     any --Cancel--> idle
///
/// An X marks every enemy the tank could hit from Tile1, so the targets always
/// follow the tile the player is pointing at. The tank never moves on screen
/// before the action is committed: the `.moved` event is what drives it.
///
/// It owns the `GameState` and is the only thing that applies actions, so the
/// scene never has to reason about rules. No SpriteKit here on purpose: the
/// whole flow is unit-testable.
///
/// With `aiSide` set (milestone 3), the tap flow stops accepting input on that
/// side's turn and the scene hands it to a `TankAI` instead. Left nil it is
/// still the hot-seat machine from milestone 2, where whoever
/// `state.currentSide` says it is gets to pick a tank.
public struct BoardInteraction: Equatable {

    /// A move being planned — "Tile1" in the Tap-flow diagram. Nothing has
    /// moved, on screen or in the rules, until a confirming tap commits it.
    public struct MovePlan: Equatable {
        public let tankID: TankID
        public let origin: Position
        /// Tile1: where the tank would act from. Starts as its own tile, so
        /// enemies already in range are marked the moment it is selected.
        public var destination: Position
        /// Tiles the tank may stop on, with their movement cost.
        public let reachable: [Position: Int]

        /// Tile1 is somewhere other than the tank's own tile.
        public var hasMoved: Bool { destination != origin }
    }

    public enum Phase: Equatable {
        case idle
        /// A tank is selected; move highlights and in-range targets are shown.
        case planning(MovePlan)
        /// A target is picked; the damage preview and Attack/Wait are shown.
        case aiming(MovePlan, targetID: TankID, preview: AttackPreview)
    }

    public private(set) var state: GameState
    public private(set) var phase: Phase = .idle

    /// The side a `TankAI` plays, or nil for hot seat.
    ///
    /// This is what stops the player from tapping out the opponent's turn
    /// while it is thinking: every input the flow accepts is gated on
    /// `acceptsInput`, not merely on whose turn it is.
    public var aiSide: Side?

    /// The tank the player last tapped to look at rather than to act on.
    ///
    /// Both sides share one hull per side, so the board cannot say which kind a
    /// tank is and the HUD has to (`docs/sprite_design.md` D2a). Without this,
    /// a tap on an enemy out of range is swallowed and there is no way to ask
    /// what it is. Purely informational: it never affects what an action does.
    public private(set) var inspectedTankID: TankID?

    public init(state: GameState, aiSide: Side? = nil) {
        self.state = state
        self.aiSide = aiSide
    }

    // MARK: - What the renderer needs to draw

    public var currentSide: Side { state.currentSide }
    public var isOver: Bool { state.isOver }

    /// True while the AI owes the game an action.
    public var isAITurn: Bool { !isOver && currentSide == aiSide }

    /// Whether a tap or a command button means anything right now.
    public var acceptsInput: Bool { !isOver && !isAITurn }

    public var plan: MovePlan? {
        switch phase {
        case .idle: return nil
        case .planning(let plan): return plan
        case .aiming(let plan, _, _): return plan
        }
    }

    public var selectedTankID: TankID? { plan?.tankID }

    /// The tank the HUD should describe: what the player is aiming at, else
    /// what they last tapped to look at, else what they have selected.
    ///
    /// Inspecting beats the selection on purpose. Asking "what is that red
    /// tank?" while your own tank is selected is the main reason to inspect at
    /// all, and answering with the tank you already picked would make the
    /// feature useless. Anything the player does with their own tank —
    /// selecting, re-pointing the move, cancelling, ending the turn — clears
    /// the inspection, so the HUD comes straight back.
    public var describedTankID: TankID? {
        aimedTargetID ?? inspectedTankID ?? selectedTankID
    }

    /// Tiles to highlight as move options. Empty unless a tank is selected.
    public var moveHighlights: [Position] {
        guard let plan else { return [] }
        return plan.reachable.keys.filter { $0 != plan.origin }
    }

    /// The route from the tank's tile to Tile1. Empty while Tile1 is the
    /// tank's own tile.
    public var plannedPath: [Position] {
        guard let plan, plan.hasMoved, let tank = state.tank(plan.tankID) else { return [] }
        return Rules.path(for: tank, to: plan.destination, in: state) ?? []
    }

    /// The route to draw as a hint. The tank itself stays put until the move
    /// is committed, so this line is the only sign of where it is going.
    public var pathHint: [Position] { plannedPath }

    /// Enemies the selected tank could hit from Tile1 — the ones that get an
    /// X. Computed through `tankAfterMove`, so driving onto the supply tile
    /// rearms the shot before it is taken, exactly as the rules will.
    public var targetableTankIDs: [TankID] {
        guard let plan, let tank = state.tank(plan.tankID) else { return [] }
        let shooter = Rules.tankAfterMove(tank, to: plan.destination, in: state)
        return Rules.attackableTargets(for: shooter, in: state).map(\.id)
    }

    public var aimedTargetID: TankID? {
        if case .aiming(_, let targetID, _) = phase { return targetID }
        return nil
    }

    /// The damage numbers to show, including the counterattack. Nil until a
    /// target is picked.
    public var attackPreview: AttackPreview? {
        if case .aiming(_, _, let preview) = phase { return preview }
        return nil
    }

    /// Tanks of the side to move that have not had their go yet. The board
    /// greys out the rest.
    public var pendingTankIDs: [TankID] {
        state.pendingTanks(of: currentSide).map(\.id)
    }

    public var canPass: Bool { acceptsInput }

    // MARK: - Input

    /// The single entry point for a tap on the board. Returns the events to
    /// animate, which is empty for every tap that only changes the selection.
    @discardableResult
    public mutating func tapTile(_ tile: Position) -> [GameEvent] {
        guard acceptsInput else { return [] }

        guard let plan else {
            select(tankAt: tile)
            return []
        }

        // An enemy with an X: the first tap shows what the shot would do, a
        // second tap on the same enemy moves to Tile1 and fires. An enemy
        // without an X cannot be hit from Tile1, so the tap only describes it.
        if let enemy = state.tank(at: tile), enemy.side != currentSide {
            guard targetableTankIDs.contains(enemy.id) else {
                inspectedTankID = enemy.id
                return []
            }
            if aimedTargetID == enemy.id {
                return commit(TankCommand(tankID: plan.tankID, destination: plan.destination,
                                          targetID: enemy.id))
            }
            aim(plan: plan, at: enemy.id)
            return []
        }

        // Tile1 again: "just move" — move there and end this tank's go. When
        // Tile1 is the tank's own tile, that is holding position. Any aim is
        // dropped: the player chose the move over the shot.
        if tile == plan.destination {
            return commit(TankCommand(tankID: plan.tankID, destination: plan.destination))
        }

        // Another reachable tile becomes Tile1. The X's are recomputed from
        // it, so any aim from the old Tile1 no longer applies.
        if plan.reachable[tile] != nil {
            var updated = plan
            updated.destination = tile
            phase = .planning(updated)
            // Back to steering our own tank, so stop describing someone else's.
            inspectedTankID = nil
            return []
        }

        // Not reachable: nothing happens and the tank stays selected. Cancel is
        // the way to drop it or switch tanks. A tank standing there is still
        // worth describing.
        inspect(tankAt: tile)
        return []
    }

    /// Gives up the rest of the side's turn, leaving every tank still waiting
    /// for orders where it stands.
    @discardableResult
    public mutating func pass() -> [GameEvent] {
        guard acceptsInput else { return [] }
        phase = .idle
        inspectedTankID = nil
        guard let result = try? Rules.apply(.pass, to: state) else { return [] }
        state = result.state
        return result.events
    }

    /// Asks `ai` for one action and applies it. Does nothing on a human turn,
    /// so the scene can call it whenever it is unsure.
    ///
    /// One action, not the whole turn: a turn is every tank of a side acting,
    /// and the scene wants to animate them one at a time. It keeps calling
    /// this while `isAITurn` holds.
    @discardableResult
    public mutating func takeAIAction(with ai: TankAI) -> [GameEvent] {
        guard isAITurn else { return [] }
        return apply(ai.chooseAction(in: state))
    }

    /// Applies an action that did not come from a tap — the AI's.
    ///
    /// Falls back to `.pass` if the rules reject it: a brain with a bug must
    /// cost the opponent its turn, not wedge the match with no way forward.
    @discardableResult
    public mutating func apply(_ action: Action) -> [GameEvent] {
        guard !isOver else { return [] }
        phase = .idle
        inspectedTankID = nil
        if let result = try? Rules.apply(action, to: state) {
            state = result.state
            return result.events
        }
        guard let fallback = try? Rules.apply(.pass, to: state) else { return [] }
        state = fallback.state
        return fallback.events
    }

    /// Drops the whole selection, from any stage. Since tapping the board no
    /// longer deselects or switches tanks, this is the only way back, so it goes
    /// all the way rather than stepping back one stage at a time.
    public mutating func cancel() {
        phase = .idle
        inspectedTankID = nil
    }


    /// Replaces the state, e.g. when the AI has moved (milestone 3) or a new
    /// match starts. Any half-finished selection is dropped.
    public mutating func reset(to state: GameState) {
        self.state = state
        self.phase = .idle
        self.inspectedTankID = nil
    }

    // MARK: - Internals

    private mutating func select(tankAt tile: Position) {
        // A tank that has already had its go this turn is no longer an option,
        // but tapping it should still say what it is rather than do nothing.
        guard let tank = state.tank(at: tile),
              tank.side == currentSide,
              !state.hasActed(tank.id) else {
            phase = .idle
            inspectedTankID = state.tank(at: tile).flatMap { $0.isAlive ? $0.id : nil }
            return
        }
        inspectedTankID = nil
        phase = .planning(MovePlan(tankID: tank.id,
                                   origin: tank.position,
                                   destination: tank.position,
                                   reachable: Rules.reachableTiles(for: tank, in: state)))
    }

    private mutating func aim(plan: MovePlan, at targetID: TankID) {
        guard let tank = state.tank(plan.tankID), let target = state.tank(targetID) else { return }
        let shooter = Rules.tankAfterMove(tank, to: plan.destination, in: state)
        let preview = Rules.preview(attacker: shooter, target: target, in: state)
        phase = .aiming(plan, targetID: targetID, preview: preview)
    }

    /// Describes whatever tank stands on `tile`, other than the selected one
    /// (which the HUD already describes).
    private mutating func inspect(tankAt tile: Position) {
        if let other = state.tank(at: tile), other.isAlive, other.id != selectedTankID {
            inspectedTankID = other.id
        }
    }

    /// Applies a command. An `IllegalAction` here would mean the UI offered
    /// something the rules reject, so the selection is cleared rather than
    /// leaving the player stuck with a dead end.
    private mutating func commit(_ command: TankCommand) -> [GameEvent] {
        phase = .idle
        inspectedTankID = nil
        guard let result = try? Rules.apply(.command(command), to: state) else { return [] }
        state = result.state
        return result.events
    }
}
