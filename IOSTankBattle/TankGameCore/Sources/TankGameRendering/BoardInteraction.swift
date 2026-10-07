import TankGameCore

/// The tap-driven turn flow, as a pure state machine:
///
///     idle --tap own tank--> planning --tap tile--> planning (new destination)
///                            |  \--tap enemy in range--> aiming --Attack--> committed
///                            \--Wait--> committed
///
/// It owns the `GameState` and is the only thing that applies actions, so the
/// scene never has to reason about rules. No SpriteKit here on purpose: the
/// whole flow is unit-testable.
///
/// Hot-seat (milestone 2): both sides are human, so whoever `state.currentSide`
/// says it is gets to pick a tank.
public struct BoardInteraction: Equatable {

    /// A move being planned. The tank has NOT moved; `destination` is where the
    /// player is currently pointing it.
    public struct MovePlan: Equatable {
        public let tankID: TankID
        public let origin: Position
        public var destination: Position
        /// Tiles the tank may stop on, with their movement cost.
        public let reachable: [Position: Int]

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

    /// The tank the player last tapped to look at rather than to act on.
    ///
    /// Both sides share one hull per side, so the board cannot say which kind a
    /// tank is and the HUD has to (`docs/sprite_design.md` D2a). Without this,
    /// a tap on an enemy out of range is swallowed and there is no way to ask
    /// what it is. Purely informational: it never affects what an action does.
    public private(set) var inspectedTankID: TankID?

    public init(state: GameState) {
        self.state = state
    }

    // MARK: - What the renderer needs to draw

    public var currentSide: Side { state.currentSide }
    public var isOver: Bool { state.isOver }

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

    /// The route the tank would drive, for a path hint. Empty if it stays put.
    public var plannedPath: [Position] {
        guard let plan, plan.hasMoved, let tank = state.tank(plan.tankID) else { return [] }
        return Rules.path(for: tank, to: plan.destination, in: state) ?? []
    }

    /// Enemies the selected tank could hit from its planned destination.
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

    /// "Wait" ends the turn with the move only; always available once a tank is
    /// selected, including when it has not moved (a deliberate skip).
    public var canWait: Bool {
        guard !isOver else { return false }
        return plan != nil
    }

    public var canAttack: Bool {
        guard !isOver else { return false }
        return aimedTargetID != nil
    }

    public var canPass: Bool { !isOver }

    // MARK: - Input

    /// The single entry point for a tap on the board. Returns the events to
    /// animate, which is empty for every tap that only changes the selection.
    @discardableResult
    public mutating func tapTile(_ tile: Position) -> [GameEvent] {
        guard !isOver else { return [] }

        guard let plan else {
            select(tankAt: tile)
            return []
        }

        // Tapping an enemy that is in range from the planned tile aims at it.
        // Out of range there is nothing to aim, so the tap inspects instead of
        // being swallowed.
        if let enemy = state.tank(at: tile), enemy.side != currentSide {
            if targetableTankIDs.contains(enemy.id) {
                aim(plan: plan, at: enemy.id)
            } else {
                inspectedTankID = enemy.id
            }
            return []
        }

        // The confirmation tap. The tank has already driven here, and tapping the
        // tile a second time is the player taking responsibility for the move:
        // it commits and ends the turn.
        if tile == plan.destination {
            // A second tap on a tank that has not moved is not a confirmation of
            // anything, and silently burning a turn would be worse than ignoring
            // it. Staying put deliberately is what the Wait button is for.
            guard plan.hasMoved else { return [] }
            return commit(TankCommand(tankID: plan.tankID, destination: plan.destination))
        }

        // Any other reachable tile re-points the move, and drops any aim because
        // range depends on where we stop. The tank drives to the new tile.
        if plan.reachable[tile] != nil {
            var updated = plan
            updated.destination = tile
            phase = .planning(updated)
            // Back to driving our own tank, so stop describing someone else's.
            inspectedTankID = nil
            return []
        }

        // Everything else leaves the plan alone — cancelling and switching tanks
        // go through the Cancel button, so a stray tap can never throw away a
        // planned move. A tank standing there is still worth describing.
        if let other = state.tank(at: tile), other.isAlive {
            inspectedTankID = other.id
        }
        return []
    }

    /// Commits the planned move without firing.
    @discardableResult
    public mutating func wait() -> [GameEvent] {
        guard let plan, !isOver else { return [] }
        return commit(TankCommand(tankID: plan.tankID, destination: plan.destination))
    }

    /// Commits the planned move and the attack on the aimed target.
    @discardableResult
    public mutating func attack() -> [GameEvent] {
        guard case .aiming(let plan, let targetID, _) = phase, !isOver else { return [] }
        return commit(TankCommand(tankID: plan.tankID, destination: plan.destination,
                                  targetID: targetID))
    }

    /// Ends the turn without doing anything.
    @discardableResult
    public mutating func pass() -> [GameEvent] {
        guard !isOver else { return [] }
        phase = .idle
        inspectedTankID = nil
        guard let result = try? Rules.apply(.pass, to: state) else { return [] }
        state = result.state
        return result.events
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
        guard let tank = state.tank(at: tile), tank.side == currentSide else {
            phase = .idle
            // Nothing selectable here, but an enemy tank is still worth a look.
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
