/// Rejected actions. The rules never mutate state on failure.
public enum IllegalAction: Error, Equatable, Sendable {
    case gameOver
    case noSuchTank(TankID)
    case tankDestroyed(TankID)
    case notYourTank(TankID)
    case tankAlreadyActed(TankID)
    case destinationUnreachable(Position)
    case noSuchTarget(TankID)
    case targetDestroyed(TankID)
    case targetIsFriendly(TankID)
    case outOfAmmo(TankID)
    case targetOutOfRange(TankID)
}

/// Everything that happened while applying one `Action`, in order.
/// The renderer replays these as animations; the AI ignores them.
public enum GameEvent: Equatable, Sendable {
    case passed(Side)
    /// `path` starts at the origin tile and ends at the destination.
    case moved(TankID, path: [Position])
    /// The tank arrived on its own supply tile and refilled HP and ammo.
    case resupplied(TankID)
    case attacked(attacker: TankID, defender: TankID, damage: Int, destroyed: Bool)
    /// Fired back by the defender of the preceding `.attacked`. Never chains.
    case counterattacked(attacker: TankID, defender: TankID, damage: Int, destroyed: Bool)
    case turnBegan(Side, round: Int)
    case gameEnded(GameResult)
}

/// What an attack would do, without applying it. Drives the UI damage preview
/// (milestone 2) and the AI's scoring (milestone 3).
public struct AttackPreview: Equatable, Sendable {
    public let damage: Int
    public let targetDestroyed: Bool
    /// Damage the defender fires back, 0 if it cannot counterattack.
    public let counterDamage: Int
    public let attackerDestroyed: Bool

    public var hasCounterattack: Bool { counterDamage > 0 }
}

/// The pure rules of the game: what is legal, and what applying an action does.
///
/// Every function takes state and returns answers or a NEW state; nothing here
/// holds mutable state of its own, so the AI can explore futures freely.
public enum Rules {

    // MARK: - Task 2: movement

    /// Movement cost to every tile this tank can reach or cross, including its
    /// own tile at cost 0. Dijkstra over orthogonal neighbours.
    ///
    /// Blocking: impassable terrain, the enemy's supply tile, and ENEMY tanks
    /// (which cannot be crossed). Friendly tanks may be crossed, so they appear
    /// here even though the tank may not stop on them.
    public static func movementCosts(for tank: Tank, in state: GameState) -> [Position: Int] {
        let budget = state.stats(of: tank).movePoints
        var costs: [Position: Int] = [tank.position: 0]
        var frontier: [Position: Int] = [tank.position: 0]
        var settled: Set<Position> = []

        while let (tile, cost) = frontier.min(by: { $0.value < $1.value }) {
            frontier[tile] = nil
            guard settled.insert(tile).inserted else { continue }

            for next in tile.orthogonalNeighbors {
                guard !settled.contains(next),
                      state.map.canEnter(next, side: tank.side),
                      let step = state.map.terrain(at: next)?.moveCost
                else { continue }
                // Enemy tanks block the way; friendly tanks can be driven through.
                if let blocker = state.tank(at: next), blocker.side != tank.side { continue }

                let total = cost + step
                guard total <= budget else { continue }
                if let known = costs[next], known <= total { continue }
                costs[next] = total
                frontier[next] = total
            }
        }
        return costs
    }

    /// Tiles this tank may END its move on: everything in `movementCosts`
    /// minus tiles occupied by another living tank. Always contains the tank's
    /// own position (staying put is legal).
    public static func reachableTiles(for tank: Tank, in state: GameState) -> [Position: Int] {
        movementCosts(for: tank, in: state).filter { tile, _ in
            tile == tank.position || state.tank(at: tile) == nil
        }
    }

    public static func canMove(_ tank: Tank, to destination: Position, in state: GameState) -> Bool {
        reachableTiles(for: tank, in: state)[destination] != nil
    }

    /// A cheapest path from the tank's tile to `destination`, inclusive at both
    /// ends, or nil if unreachable. Used to animate the drive (milestone 2).
    public static func path(for tank: Tank, to destination: Position, in state: GameState) -> [Position]? {
        let costs = movementCosts(for: tank, in: state)
        guard costs[destination] != nil else { return nil }

        // Walk backwards, always stepping to a neighbour whose cost is exactly
        // our cost minus the cost of entering the tile we came from.
        var path = [destination]
        var tile = destination
        while tile != tank.position {
            guard let cost = costs[tile],
                  let step = state.map.terrain(at: tile)?.moveCost,
                  let previous = tile.orthogonalNeighbors.first(where: { costs[$0] == cost - step })
            else { return nil }
            path.append(previous)
            tile = previous
        }
        return path.reversed()
    }

    /// The tank as it will be once it has driven to `destination`, including the
    /// supply-tile refill. Lets the UI and the AI preview an attack from a
    /// planned tile without applying anything.
    public static func tankAfterMove(_ tank: Tank, to destination: Position,
                                     in state: GameState) -> Tank {
        var moved = tank
        moved.position = destination
        // Task 5: only ARRIVING refills, so standing still changes nothing.
        if destination != tank.position, state.map.supplyOwner(at: destination) == tank.side {
            let stats = state.stats(of: tank)
            moved.hp = stats.maxHP
            moved.ammo = stats.maxAmmo
        }
        return moved
    }

    // MARK: - Task 3: targets

    /// Enemy tanks this tank could shoot, optionally from a hypothetical tile
    /// (pass the destination of a planned move). Empty when out of ammo.
    public static func attackableTargets(for tank: Tank,
                                         from origin: Position? = nil,
                                         in state: GameState) -> [Tank] {
        guard tank.isAlive, tank.hasAmmo else { return [] }
        let shooter = origin ?? tank.position
        let stats = state.stats(of: tank)
        return state.aliveTanks(of: tank.side.opponent).filter {
            stats.canReach(distance: shooter.manhattanDistance(to: $0.position))
        }
    }

    public static func canAttack(_ attacker: Tank, _ target: Tank,
                                 from origin: Position? = nil,
                                 in state: GameState) -> Bool {
        guard attacker.isAlive, attacker.hasAmmo, target.isAlive,
              target.side != attacker.side else { return false }
        let shooter = origin ?? attacker.position
        return state.stats(of: attacker)
            .canReach(distance: shooter.manhattanDistance(to: target.position))
    }

    // MARK: - Task 4: combat

    /// Resolves an attack on paper: damage, the kill, and the single
    /// counterattack. No randomness, so this is exactly what `apply` will do.
    public static func preview(attacker: Tank, target: Tank,
                               from origin: Position? = nil,
                               in state: GameState) -> AttackPreview {
        let shooter = origin ?? attacker.position
        let damage = min(state.stats(of: attacker).damage, target.hp)
        let targetHP = target.hp - damage

        // The defender fires back only if it survived, has a shot left, and the
        // attacker is inside the DEFENDER's own range band.
        let defenderStats = state.stats(of: target)
        let canCounter = targetHP > 0 && target.hasAmmo
            && defenderStats.canReach(distance: target.position.manhattanDistance(to: shooter))
        let counterDamage = canCounter ? min(defenderStats.damage, attacker.hp) : 0

        return AttackPreview(damage: damage,
                             targetDestroyed: targetHP <= 0,
                             counterDamage: counterDamage,
                             attackerDestroyed: attacker.hp - counterDamage <= 0)
    }

    // MARK: - Tasks 5-7: applying an action

    /// Applies one action and hands back the next state plus the events to
    /// animate. Throws `IllegalAction` and changes nothing if the action is not
    /// legal, so callers may offer candidates optimistically.
    @discardableResult
    public static func apply(_ action: Action,
                             to state: GameState) throws -> (state: GameState, events: [GameEvent]) {
        guard !state.isOver else { throw IllegalAction.gameOver }

        var next = state
        var events: [GameEvent] = []

        switch action {
        case .pass:
            events.append(.passed(state.currentSide))

        case .command(let command):
            try perform(command, in: &next, events: &events)
        }

        // Passing gives up the rest of the turn; otherwise the side keeps the
        // board until every one of its tanks has had a go.
        advanceTurn(in: &next, endingTurn: action == .pass, events: &events)
        return (next, events)
    }

    /// Move first, then shoot. `state` here is always `apply`'s private copy, so
    /// throwing part-way through leaves the caller's state untouched; that is
    /// what lets the attack be checked against the POST-move tank (which may
    /// just have rearmed on its supply tile).
    private static func perform(_ command: TankCommand,
                                in state: inout GameState,
                                events: inout [GameEvent]) throws {
        guard let tank = state.tank(command.tankID) else {
            throw IllegalAction.noSuchTank(command.tankID)
        }
        guard tank.isAlive else { throw IllegalAction.tankDestroyed(command.tankID) }
        guard tank.side == state.currentSide else { throw IllegalAction.notYourTank(command.tankID) }
        // One action per tank per turn.
        guard !state.hasActed(tank.id) else { throw IllegalAction.tankAlreadyActed(command.tankID) }
        state.actedThisTurn.insert(tank.id)

        // 1. Move.
        let origin = tank.position
        let destination = command.destination
        if destination != origin {
            guard let drive = path(for: tank, to: destination, in: state),
                  canMove(tank, to: destination, in: state)
            else { throw IllegalAction.destinationUnreachable(destination) }

            let moved = tankAfterMove(tank, to: destination, in: state)
            state.tanks[tank.id] = moved
            events.append(.moved(tank.id, path: drive))

            // Task 5: arriving on your own supply tile refills HP and ammo.
            if state.map.supplyOwner(at: destination) == tank.side {
                events.append(.resupplied(tank.id))
            }
        }

        // 2. Attack, from wherever the tank now stands and with whatever ammo
        // it now has.
        guard let targetID = command.targetID else { return }
        let shooter = state.tanks[tank.id]
        guard let target = state.tank(targetID) else { throw IllegalAction.noSuchTarget(targetID) }
        guard target.isAlive else { throw IllegalAction.targetDestroyed(targetID) }
        guard target.side != shooter.side else { throw IllegalAction.targetIsFriendly(targetID) }
        guard shooter.hasAmmo else { throw IllegalAction.outOfAmmo(command.tankID) }
        guard state.stats(of: shooter)
            .canReach(distance: destination.manhattanDistance(to: target.position))
        else { throw IllegalAction.targetOutOfRange(targetID) }

        resolveAttack(attackerID: shooter.id, targetID: targetID, in: &state, events: &events)
    }

    /// One exchange of fire: the shot, then at most one counterattack.
    private static func resolveAttack(attackerID: TankID, targetID: TankID,
                                      in state: inout GameState,
                                      events: inout [GameEvent]) {
        let attacker = state.tanks[attackerID]
        let target = state.tanks[targetID]
        let shot = preview(attacker: attacker, target: target, in: state)

        state.tanks[attackerID].ammo -= 1
        state.tanks[targetID].hp -= shot.damage
        events.append(.attacked(attacker: attackerID, defender: targetID,
                                damage: shot.damage, destroyed: shot.targetDestroyed))

        guard shot.hasCounterattack else { return }
        state.tanks[targetID].ammo -= 1
        state.tanks[attackerID].hp -= shot.counterDamage
        events.append(.counterattacked(attacker: targetID, defender: attackerID,
                                       damage: shot.counterDamage,
                                       destroyed: shot.attackerDestroyed))
    }

    // MARK: - Tasks 6-7: turn flow and end conditions

    /// Ends the side's turn when it is over, counts the round, and ends the
    /// match when someone has won.
    ///
    /// A turn is every tank of one side acting, so most actions leave the board
    /// exactly where it is and this does nothing but check for a winner.
    private static func advanceTurn(in state: inout GameState, endingTurn: Bool,
                                    events: inout [GameEvent]) {
        if let result = annihilationResult(in: state) {
            finish(state: &state, with: result, events: &events)
            return
        }

        // Still tanks waiting for orders, and the side has not passed: the
        // board stays where it is.
        guard endingTurn || state.isTurnComplete else { return }
        state.actedThisTurn = []

        // A round is over once the side that moves second has taken its turn.
        let secondSide = state.config.firstSide.opponent
        let roundComplete = state.currentSide == secondSide
        state.currentSide = state.currentSide.opponent
        if roundComplete {
            guard state.round < state.config.maxRounds else {
                finish(state: &state, with: hpResult(in: state), events: &events)
                return
            }
            state.round += 1
        }
        events.append(.turnBegan(state.currentSide, round: state.round))
    }

    private static func finish(state: inout GameState, with result: GameResult,
                               events: inout [GameEvent]) {
        state.status = .finished(result)
        events.append(.gameEnded(result))
    }

    /// A decided result if one or both armies are wiped out, else nil.
    public static func annihilationResult(in state: GameState) -> GameResult? {
        let playerLives = !state.aliveTanks(of: .player).isEmpty
        let aiLives = !state.aliveTanks(of: .ai).isEmpty
        switch (playerLives, aiLives) {
        case (true, true): return nil
        case (false, false): return .draw           // mutual destruction by counterattack
        case (true, false): return .win(.player, .annihilation)
        case (false, true): return .win(.ai, .annihilation)
        }
    }

    /// Who wins on total remaining HP, used when the round limit runs out.
    public static func hpResult(in state: GameState) -> GameResult {
        let player = state.totalHP(of: .player)
        let ai = state.totalHP(of: .ai)
        if player == ai { return .draw }
        return .win(player > ai ? .player : .ai, .moreHPAtRoundLimit)
    }
}
