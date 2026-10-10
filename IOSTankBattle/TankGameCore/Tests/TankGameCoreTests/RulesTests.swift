import XCTest
@testable import TankGameCore

// MARK: - Test helpers

/// Builds a state directly from an ASCII map and an explicit tank list, so each
/// test can set up the exact board it cares about instead of a full match.
private func makeState(_ ascii: String,
                       tanks: [Tank],
                       config: GameConfig = .phase1Default,
                       currentSide: Side = .player,
                       round: Int = 1) throws -> GameState {
    GameState(config: config, map: try GameMap(ascii: ascii), tanks: tanks,
              currentSide: currentSide, round: round, status: .ongoing)
}

/// A tank with full HP and ammo for its kind, with `id` matching its index.
private func tank(_ id: TankID, _ side: Side, _ kind: TankKind, _ x: Int, _ y: Int,
                  hp: Int? = nil, ammo: Int? = nil,
                  config: GameConfig = .phase1Default) -> Tank {
    let stats = config.stats(for: kind)
    return Tank(id: id, side: side, kind: kind, position: Position(x: x, y: y),
                hp: hp ?? stats.maxHP, ammo: ammo ?? stats.maxAmmo)
}

private func p(_ x: Int, _ y: Int) -> Position { Position(x: x, y: y) }

private func isCounterattack(_ event: GameEvent) -> Bool {
    if case .counterattacked = event { return true }
    return false
}

/// 5x5, supplies in opposite corners, one spawn per side. Row 2 is a wall of
/// terrain used by the movement tests.
///
///     S....
///     .....
///     .TR..
///     .....
///     P...s      (AI spawn `a` sits at (4,4) in the variants below)
private let openMap = """
    S...a
    .....
    .....
    .....
    P...s
    """

final class MovementTests: XCTestCase {

    func testCostsUseTerrainAndRespectBudget() throws {
        // A light tank (5 move points) in the middle of an open 5x5 board.
        let state = try makeState(openMap, tanks: [tank(0, .player, .light, 2, 2)])
        let costs = Rules.movementCosts(for: state.tanks[0], in: state)

        XCTAssertEqual(costs[p(2, 2)], 0, "Own tile costs nothing")
        XCTAssertEqual(costs[p(2, 1)], 1)
        XCTAssertEqual(costs[p(2, 0)], 2)
        // Everything in range is within the 5-point budget on a 5x5 open board,
        // except the enemy supply tile, which this side may not enter.
        XCTAssertNil(costs[p(4, 4)], "Enemy supply tile is off limits")
        XCTAssertNotNil(costs[p(0, 0)], "Own supply tile is enterable")
    }

    func testTreesCostTwoAndRocksAndWaterBlock() throws {
        let map = """
            S.T.a
            .RW..
            .....
            .....
            P...s
            """
        let state = try makeState(map, tanks: [tank(0, .player, .light, 0, 0)])
        let costs = Rules.movementCosts(for: state.tanks[0], in: state)

        XCTAssertEqual(costs[p(1, 0)], 1)
        XCTAssertEqual(costs[p(2, 0)], 3, "Entering trees costs 2 on top of the 1 to reach them")
        XCTAssertNil(costs[p(1, 1)], "Rocks are impassable")
        XCTAssertNil(costs[p(2, 1)], "Water is impassable")
    }

    func testBudgetIsAHardLimit() throws {
        // Artillery has only 2 move points.
        let state = try makeState(openMap, tanks: [tank(0, .player, .artillery, 0, 2)])
        let costs = Rules.movementCosts(for: state.tanks[0], in: state)

        XCTAssertEqual(costs[p(2, 2)], 2)
        XCTAssertNil(costs[p(3, 2)], "3 tiles away is beyond a 2-point budget")
    }

    func testTreesEatIntoTheBudget() throws {
        let map = """
            S....
            .....
            TT..a
            .....
            P...s
            """
        // Artillery (2 points) starting left of two tree tiles: it can enter the
        // first (cost 2) but not the second.
        let state = try makeState(map, tanks: [tank(0, .player, .artillery, 0, 2)])
        let costs = Rules.movementCosts(for: state.tanks[0], in: state)

        XCTAssertEqual(costs[p(0, 2)], 0)
        XCTAssertEqual(costs[p(1, 2)], 2)
        XCTAssertNil(costs[p(2, 2)], "Would cost 3 with the detour, over budget")
    }

    func testPassesThroughFriendlyButNotEnemyTanks() throws {
        // A river leaves exactly one lane open, the column x = 2.
        let map = """
            Sa..s
            WW.WW
            WW.WW
            WW.WW
            P...P
            """
        let friendlyBlocked = try makeState(map, tanks: [
            tank(0, .player, .light, 2, 3),
            tank(1, .player, .medium, 2, 2),   // friendly standing in the lane
        ])
        let throughFriend = Rules.movementCosts(for: friendlyBlocked.tanks[0], in: friendlyBlocked)
        XCTAssertEqual(throughFriend[p(2, 2)], 1, "Friendly tile can be crossed")
        XCTAssertEqual(throughFriend[p(2, 1)], 2, "And we can continue past it")
        XCTAssertNil(Rules.reachableTiles(for: friendlyBlocked.tanks[0], in: friendlyBlocked)[p(2, 2)],
                     "But we may not STOP on a friendly tank")

        let enemyBlocked = try makeState(map, tanks: [
            tank(0, .player, .light, 2, 3),
            tank(1, .ai, .medium, 2, 2),       // enemy standing in the lane
        ])
        let throughEnemy = Rules.movementCosts(for: enemyBlocked.tanks[0], in: enemyBlocked)
        XCTAssertNil(throughEnemy[p(2, 2)], "Enemy tanks cannot be entered")
        XCTAssertNil(throughEnemy[p(2, 1)], "...nor crossed to reach what is behind them")
    }

    func testMayNotEndOnOccupiedTileButMayStayPut() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 2, 2),
            tank(1, .player, .medium, 2, 1),
            tank(2, .ai, .medium, 3, 2),
        ])
        let reachable = Rules.reachableTiles(for: state.tanks[0], in: state)

        XCTAssertNotNil(reachable[p(2, 2)], "Staying in place is always legal")
        XCTAssertNil(reachable[p(2, 1)], "Occupied by a friend")
        XCTAssertNil(reachable[p(3, 2)], "Occupied by an enemy")
        XCTAssertNotNil(reachable[p(1, 2)])
    }

    func testOnlyTheOwnerMayEnterASupplyTile() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 1, 0),
            tank(1, .ai, .light, 3, 0),
        ])
        XCTAssertTrue(Rules.canMove(state.tanks[0], to: p(0, 0), in: state),
                      "Player may enter the player supply tile")
        XCTAssertFalse(Rules.canMove(state.tanks[1], to: p(0, 0), in: state),
                       "AI may not enter the player supply tile")
    }

    func testPathIsContiguousAndRoutesAroundObstacles() throws {
        let map = """
            S.R.a
            .....
            .....
            .....
            P...s
            """
        let state = try makeState(map, tanks: [tank(0, .player, .light, 0, 0)])
        let route = Rules.path(for: state.tanks[0], to: p(3, 0), in: state)

        let path = try XCTUnwrap(route)
        XCTAssertEqual(path.first, p(0, 0))
        XCTAssertEqual(path.last, p(3, 0))
        for (a, b) in zip(path, path.dropFirst()) {
            XCTAssertEqual(a.manhattanDistance(to: b), 1, "Path must be single orthogonal steps")
        }
        XCTAssertFalse(path.contains(p(2, 0)), "The route goes around the rocks, not through them")
        XCTAssertEqual(path.count - 1, 5, "Shortest way around is 5 steps")
    }

    func testPathToUnreachableTileIsNil() throws {
        let state = try makeState(openMap, tanks: [tank(0, .player, .artillery, 0, 0)])
        XCTAssertNil(Rules.path(for: state.tanks[0], to: p(4, 3), in: state))
    }
}

final class TargetingTests: XCTestCase {

    func testRangeBandIsInclusiveAndUsesManhattan() throws {
        // Medium tank: range 1-2.
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .medium, 0, 0),
            tank(1, .ai, .light, 2, 0),        // distance 2: in range
            tank(2, .ai, .light, 3, 0),        // distance 3: out of range
            tank(3, .ai, .light, 1, 1),        // distance 2 (diagonal): in range
        ])
        let targets = Rules.attackableTargets(for: state.tanks[0], in: state).map(\.id)
        XCTAssertEqual(Set(targets), [1, 3])
    }

    func testArtilleryCannotHitAdjacentTargets() throws {
        // Artillery: range 2-4.
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .artillery, 0, 0),
            tank(1, .ai, .light, 1, 0),        // adjacent: inside the dead zone
            tank(2, .ai, .light, 2, 0),        // distance 2: fine
        ])
        let targets = Rules.attackableTargets(for: state.tanks[0], in: state).map(\.id)
        XCTAssertEqual(targets, [2])
    }

    func testNoAmmoMeansNoTargets() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 0, ammo: 0),
            tank(1, .ai, .light, 1, 0),
        ])
        XCTAssertTrue(Rules.attackableTargets(for: state.tanks[0], in: state).isEmpty)
        XCTAssertFalse(Rules.canAttack(state.tanks[0], state.tanks[1], in: state))
    }

    func testDestroyedTanksAreNeitherShootersNorTargets() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 0),
            tank(1, .ai, .light, 1, 0, hp: 0),      // destroyed
            tank(2, .player, .light, 2, 0, hp: 0),  // destroyed
            tank(3, .ai, .light, 3, 0),
        ])
        XCTAssertTrue(Rules.attackableTargets(for: state.tanks[0], in: state).isEmpty,
                      "A destroyed enemy is not a target")
        XCTAssertTrue(Rules.attackableTargets(for: state.tanks[2], in: state).isEmpty,
                      "A destroyed tank cannot shoot")
    }

    func testFriendlyFireIsNotAllowed() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 0),
            tank(1, .player, .light, 1, 0),
        ])
        XCTAssertFalse(Rules.canAttack(state.tanks[0], state.tanks[1], in: state))
    }

    func testTargetsCanBeCheckedFromAPlannedDestination() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 0),    // range 1, currently 3 away
            tank(1, .ai, .light, 3, 0),
        ])
        XCTAssertTrue(Rules.attackableTargets(for: state.tanks[0], in: state).isEmpty)
        let afterMove = Rules.attackableTargets(for: state.tanks[0], from: p(2, 0), in: state)
        XCTAssertEqual(afterMove.map(\.id), [1], "Moving adjacent brings the target into range")
    }
}

final class CombatTests: XCTestCase {

    func testDamageAmmoAndCounterattack() throws {
        // Two mediums (damage 4, HP 10, range 1-2) standing adjacent.
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .medium, 1, 1),
            tank(1, .ai, .medium, 2, 1),
        ])
        let result = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(1, 1), targetID: 1)),
                                     to: state)
        state = result.state

        XCTAssertEqual(state.tanks[1].hp, 6, "Defender took 4")
        XCTAssertEqual(state.tanks[0].hp, 6, "Attacker took 4 back")
        XCTAssertEqual(state.tanks[0].ammo, 4, "Attacker spent a shell")
        XCTAssertEqual(state.tanks[1].ammo, 4, "Defender spent one on the counterattack")
        XCTAssertEqual(result.events.count(where: isCounterattack), 1)
    }

    func testCounterattackNeedsTheAttackerInsideTheDEFENDERSRange() throws {
        // Player medium (range 1-2) shoots from distance 2.
        // The AI light has range 1, so it cannot shoot back.
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .medium, 0, 0),
            tank(1, .ai, .light, 2, 0),
        ])
        let preview = Rules.preview(attacker: state.tanks[0], target: state.tanks[1], in: state)
        XCTAssertEqual(preview.damage, 4)
        XCTAssertFalse(preview.hasCounterattack)

        state = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(0, 0), targetID: 1)),
                                to: state).state
        XCTAssertEqual(state.tanks[0].hp, 10, "Untouched: the light tank could not reach back")
        XCTAssertEqual(state.tanks[1].ammo, 6, "And so it spent no ammo")
    }

    func testArtilleryIsSafeFromCounterattackAtRange() throws {
        // Artillery (damage 5, range 2-4) shells a medium (range 1-2) from 3 tiles.
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .artillery, 0, 0),
            tank(1, .ai, .medium, 3, 0),
        ])
        let preview = Rules.preview(attacker: state.tanks[0], target: state.tanks[1], in: state)
        XCTAssertEqual(preview.damage, 5)
        XCTAssertEqual(preview.counterDamage, 0)
    }

    func testDefenderWithoutAmmoCannotCounterattack() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .medium, 1, 1),
            tank(1, .ai, .medium, 2, 1, ammo: 0),
        ])
        XCTAssertFalse(Rules.preview(attacker: state.tanks[0], target: state.tanks[1], in: state)
            .hasCounterattack)
    }

    func testDestroyedDefenderDoesNotCounterattack() throws {
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .medium, 1, 1),
            tank(1, .ai, .medium, 2, 1, hp: 3),   // 4 damage kills it
        ])
        let result = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(1, 1), targetID: 1)),
                                     to: state)
        state = result.state

        XCTAssertEqual(state.tanks[1].hp, 0)
        XCTAssertFalse(state.tanks[1].isAlive)
        XCTAssertEqual(state.tanks[0].hp, 10, "A dead tank fires no parting shot")
        XCTAssertTrue(result.events.contains(.attacked(attacker: 0, defender: 1, damage: 3, destroyed: true)),
                      "Damage is reported capped at the target's remaining HP")
    }

    func testCounterattackCanDestroyTheAttackerButNeverChains() throws {
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 1, 1, hp: 2),   // light: damage 3, range 1
            tank(1, .ai, .medium, 2, 1),             // medium: damage 4, survives
        ])
        let result = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(1, 1), targetID: 1)),
                                     to: state)
        state = result.state

        XCTAssertEqual(state.tanks[1].hp, 7, "Took the light tank's 3")
        XCTAssertEqual(state.tanks[0].hp, 0, "And killed it with the counterattack")
        XCTAssertEqual(result.events.count(where: isCounterattack), 1,
                       "Exactly one counterattack, never a chain")
    }

    func testHPAndAmmoNeverGoNegative() throws {
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .artillery, 0, 0),      // damage 5
            tank(1, .ai, .light, 2, 0, hp: 1),
        ])
        state = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(0, 0), targetID: 1)),
                                to: state).state
        XCTAssertEqual(state.tanks[1].hp, 0, "Overkill clamps to 0, it does not go negative")
    }

    func testAttackIsRejectedWhenOutOfRangeOrOutOfAmmo() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 0),
            tank(1, .ai, .light, 3, 0),
            tank(2, .player, .light, 1, 2, ammo: 0),
            tank(3, .ai, .light, 1, 3),
        ])
        XCTAssertThrowsError(
            try Rules.apply(.command(TankCommand(tankID: 0, destination: p(0, 0), targetID: 1)), to: state)
        ) { XCTAssertEqual($0 as? IllegalAction, .targetOutOfRange(1)) }

        XCTAssertThrowsError(
            try Rules.apply(.command(TankCommand(tankID: 2, destination: p(1, 2), targetID: 3)), to: state)
        ) { XCTAssertEqual($0 as? IllegalAction, .outOfAmmo(2)) }
    }

    func testMoveThenAttackUsesTheNewPosition() throws {
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 0),    // range 1
            tank(1, .ai, .medium, 3, 0),
        ])
        // Driving to (2,0) puts the target one tile away.
        state = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(2, 0), targetID: 1)),
                                to: state).state
        XCTAssertEqual(state.tanks[0].position, p(2, 0))
        XCTAssertEqual(state.tanks[1].hp, 7, "Took the light tank's 3 after the move")
    }

    func testAnIllegalMoveLeavesTheStateUntouched() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .artillery, 0, 0),
            tank(1, .ai, .light, 1, 0),
        ])
        XCTAssertThrowsError(
            try Rules.apply(.command(TankCommand(tankID: 0, destination: p(4, 2))), to: state)
        ) { XCTAssertEqual($0 as? IllegalAction, .destinationUnreachable(p(4, 2))) }
    }

    func testCommandingTheWrongTankIsRejected() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 0),
            tank(1, .ai, .light, 3, 0),
        ], currentSide: .player)

        XCTAssertThrowsError(
            try Rules.apply(.command(TankCommand(tankID: 1, destination: p(3, 1))), to: state)
        ) { XCTAssertEqual($0 as? IllegalAction, .notYourTank(1)) }

        XCTAssertThrowsError(
            try Rules.apply(.command(TankCommand(tankID: 99, destination: p(0, 1))), to: state)
        ) { XCTAssertEqual($0 as? IllegalAction, .noSuchTank(99)) }
    }
}

final class SupplyTests: XCTestCase {

    func testArrivingOnYourSupplyTileRefillsHPAndAmmo() throws {
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .medium, 1, 0, hp: 2, ammo: 1),
        ])
        let result = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(0, 0))), to: state)
        state = result.state

        XCTAssertEqual(state.tanks[0].hp, 10)
        XCTAssertEqual(state.tanks[0].ammo, 5)
        XCTAssertTrue(result.events.contains(.resupplied(0)))
    }

    func testStayingOnTheTileDoesNotRefillAgain() throws {
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .medium, 0, 0, hp: 2, ammo: 1),  // already standing on supply
        ])
        let result = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(0, 0))), to: state)
        state = result.state

        XCTAssertEqual(state.tanks[0].hp, 2, "No refill without arriving")
        XCTAssertEqual(state.tanks[0].ammo, 1)
        XCTAssertFalse(result.events.contains(.resupplied(0)))
    }

    func testLeavingAndComingBackRefills() throws {
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 0, hp: 2, ammo: 0),
            tank(1, .ai, .light, 3, 3),                      // keeps the match alive
        ])
        state = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(1, 0))), to: state).state
        XCTAssertEqual(state.tanks[0].hp, 2, "Still damaged after driving off")

        state = try Rules.apply(.pass, to: state).state      // the AI's turn
        state = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(0, 0))), to: state).state
        XCTAssertEqual(state.tanks[0].hp, 6, "Refilled on the return trip")
        XCTAssertEqual(state.tanks[0].ammo, 6)
    }

    func testRefillHappensBeforeTheAttackSoARearmedTankCanFire() throws {
        // A dry light tank one tile off its supply, with an enemy sitting next
        // to that supply tile: drive on, rearm, and shoot in the same turn.
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 1, 0, ammo: 0),
            tank(1, .ai, .light, 0, 1),
        ])
        state = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(0, 0), targetID: 1)),
                                to: state).state

        XCTAssertEqual(state.tanks[1].hp, 3, "The resupplied tank fired the same turn")
        XCTAssertEqual(state.tanks[0].ammo, 5, "Refilled to 6, then spent one")
    }

    func testEnemySupplyTileCannotBeUsed() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .ai, .light, 1, 0, hp: 1, ammo: 0),
        ], currentSide: .ai)
        XCTAssertThrowsError(
            try Rules.apply(.command(TankCommand(tankID: 0, destination: p(0, 0))), to: state)
        ) { XCTAssertEqual($0 as? IllegalAction, .destinationUnreachable(p(0, 0))) }
    }
}

final class TurnFlowTests: XCTestCase {

    func testSidesAlternateAndRoundsCount() throws {
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 1, 1),
            tank(1, .ai, .light, 3, 3),
        ])
        XCTAssertEqual(state.currentSide, .player, "The player always moves first")
        XCTAssertEqual(state.round, 1)

        state = try Rules.apply(.pass, to: state).state
        XCTAssertEqual(state.currentSide, .ai)
        XCTAssertEqual(state.round, 1, "Still the same round: the AI has not had its turn")

        state = try Rules.apply(.pass, to: state).state
        XCTAssertEqual(state.currentSide, .player)
        XCTAssertEqual(state.round, 2, "A round is one turn from each side")
    }

    // MARK: A turn is one action per tank

    func testTheSideKeepsTheBoardUntilEveryTankHasActed() throws {
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 0),
            tank(1, .player, .medium, 1, 0),
            tank(2, .ai, .light, 4, 4),
        ])
        XCTAssertEqual(state.pendingTanks(of: .player).map(\.id), [0, 1])

        state = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(0, 1))),
                                to: state).state
        XCTAssertEqual(state.currentSide, .player, "One tank moved; the turn is not over")
        XCTAssertTrue(state.hasActed(0))
        XCTAssertEqual(state.pendingTanks(of: .player).map(\.id), [1])
        XCTAssertFalse(state.isTurnComplete)

        state = try Rules.apply(.command(TankCommand(tankID: 1, destination: p(1, 1))),
                                to: state).state
        XCTAssertEqual(state.currentSide, .ai, "Every tank has acted, so the turn is over")
    }

    func testTheHandOverGivesEveryTankItsGoBack() throws {
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 0),
            tank(1, .ai, .light, 4, 4),
        ])
        state = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(0, 1))),
                                to: state).state

        XCTAssertEqual(state.currentSide, .ai)
        XCTAssertTrue(state.actedThisTurn.isEmpty, "The record belongs to the turn, not the tank")
        XCTAssertEqual(state.pendingTanks(of: .ai).map(\.id), [1])
        XCTAssertFalse(state.hasActed(0), "Blue's tank gets its go back next turn")
    }

    func testATankOnlyActsOncePerTurn() throws {
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 0),
            tank(1, .player, .medium, 1, 0),
            tank(2, .ai, .light, 4, 4),
        ])
        state = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(0, 1))),
                                to: state).state

        XCTAssertThrowsError(try Rules.apply(
            .command(TankCommand(tankID: 0, destination: p(0, 2))), to: state)) {
            XCTAssertEqual($0 as? IllegalAction, .tankAlreadyActed(0))
        }
    }

    func testPassingGivesUpTheRestOfTheTurn() throws {
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 0),
            tank(1, .player, .medium, 1, 0),
            tank(2, .ai, .light, 4, 4),
        ])
        state = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(0, 1))),
                                to: state).state
        XCTAssertEqual(state.currentSide, .player)

        state = try Rules.apply(.pass, to: state).state
        XCTAssertEqual(state.currentSide, .ai, "Pass ends the turn, tanks waiting or not")
        XCTAssertEqual(state.tanks[1].position, p(1, 0), "...and the tank that was left stays put")
    }

    func testDestroyedTanksDoNotHoldTheTurnOpen() throws {
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 0),
            tank(1, .player, .medium, 1, 0, hp: 0),
            tank(2, .ai, .light, 4, 4),
        ])
        XCTAssertEqual(state.pendingTanks(of: .player).map(\.id), [0])

        state = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(0, 1))),
                                to: state).state
        XCTAssertEqual(state.currentSide, .ai, "The only living tank acted")
    }

    func testATankKilledByTheCounterattackStillSpentItsTurn() throws {
        // Blue's light attacks and dies to the medium firing back. It has had
        // its go, so with nobody else waiting the turn passes.
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 1, 1, hp: 2),
            tank(1, .ai, .medium, 1, 2),
        ])
        state = try Rules.apply(
            .command(TankCommand(tankID: 0, destination: p(1, 1), targetID: 1)), to: state).state

        XCTAssertFalse(state.tanks[0].isAlive)
        XCTAssertEqual(state.status, .finished(.win(.ai, .annihilation)))
    }

    func testTurnBeganIsOnlyReportedWhenTheSideActuallyChanges() throws {
        // The renderer uses this event to announce the turn, so it must not
        // fire between two tanks of the same side.
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 0),
            tank(1, .player, .medium, 1, 0),
            tank(2, .ai, .light, 4, 4),
        ])

        let first = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(0, 1))),
                                    to: state)
        state = first.state
        XCTAssertFalse(first.events.contains { if case .turnBegan = $0 { return true } else { return false } },
                       "Still Blue's turn")

        let second = try Rules.apply(.command(TankCommand(tankID: 1, destination: p(1, 1))),
                                     to: state)
        XCTAssertTrue(second.events.contains(.turnBegan(.ai, round: 1)))
    }

    func testPassEmitsAnEventAndChangesNothingElse() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 1, 1),
            tank(1, .ai, .light, 3, 3),
        ])
        let result = try Rules.apply(.pass, to: state)
        XCTAssertEqual(result.events.first, .passed(.player))
        XCTAssertEqual(result.state.tanks, state.tanks)
    }

    func testActingAfterTheGameIsOverIsRejected() throws {
        var state = try makeState(openMap, tanks: [tank(0, .player, .light, 1, 1)])
        state.status = .finished(.draw)
        XCTAssertThrowsError(try Rules.apply(.pass, to: state)) {
            XCTAssertEqual($0 as? IllegalAction, .gameOver)
        }
    }

    func testRoundsCountFullTurns() throws {
        // Two tanks a side: a round is four actions now, not two.
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 0),
            tank(1, .player, .medium, 1, 0),
            tank(2, .ai, .light, 4, 4),
            tank(3, .ai, .medium, 3, 4),
        ])
        let moves: [TankCommand] = [
            TankCommand(tankID: 0, destination: p(0, 1)),
            TankCommand(tankID: 1, destination: p(1, 1)),
            TankCommand(tankID: 2, destination: p(4, 3)),
            TankCommand(tankID: 3, destination: p(3, 3)),
        ]
        for move in moves {
            XCTAssertEqual(state.round, 1)
            state = try Rules.apply(.command(move), to: state).state
        }
        XCTAssertEqual(state.round, 2)
        XCTAssertEqual(state.currentSide, .player)
    }

    func testTurnEventsReportTheNewSideAndRound() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 1, 1),
            tank(1, .ai, .light, 3, 3),
        ])
        let events = try Rules.apply(.pass, to: state).events
        XCTAssertTrue(events.contains(.turnBegan(.ai, round: 1)))
    }
}

final class EndConditionTests: XCTestCase {

    func testDestroyingTheLastEnemyTankWinsByAnnihilation() throws {
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .medium, 1, 1),
            tank(1, .ai, .light, 2, 1, hp: 1, ammo: 0),
        ])
        let result = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(1, 1), targetID: 1)),
                                     to: state)
        state = result.state

        XCTAssertEqual(state.status, .finished(.win(.player, .annihilation)))
        XCTAssertTrue(state.isOver)
        XCTAssertTrue(result.events.contains(.gameEnded(.win(.player, .annihilation))))
    }

    func testLosingYourLastTankToACounterattackLosesTheGame() throws {
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 1, 1, hp: 1),   // our last tank, dies to the counterattack
            tank(1, .ai, .medium, 2, 1),             // survives the light tank's 3 damage
        ])
        state = try Rules.apply(.command(TankCommand(tankID: 0, destination: p(1, 1), targetID: 1)),
                                to: state).state

        XCTAssertFalse(state.tanks[0].isAlive)
        XCTAssertTrue(state.tanks[1].isAlive)
        XCTAssertEqual(state.status, .finished(.win(.ai, .annihilation)))
    }

    func testBothArmiesWipedOutIsADraw() throws {
        // Not reachable in play (a destroyed defender never counterattacks), but
        // the rule is defined, so it is pinned down here.
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 1, 1, hp: 0),
            tank(1, .ai, .light, 3, 3, hp: 0),
        ])
        XCTAssertEqual(Rules.annihilationResult(in: state), .draw)
    }

    func testRoundLimitIsDecidedOnTotalHP() throws {
        var config = GameConfig.phase1Default
        config.maxRounds = 2
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .medium, 1, 1, hp: 9),
            tank(1, .ai, .medium, 3, 3, hp: 4),
        ], config: config)

        for _ in 0..<3 {                       // player, AI, player
            state = try Rules.apply(.pass, to: state).state
            XCTAssertFalse(state.isOver)
        }
        state = try Rules.apply(.pass, to: state).state   // AI completes round 2

        XCTAssertEqual(state.round, 2, "The round counter stops at the limit")
        XCTAssertEqual(state.status, .finished(.win(.player, .moreHPAtRoundLimit)))
    }

    func testEqualHPAtTheRoundLimitIsADraw() throws {
        var config = GameConfig.phase1Default
        config.maxRounds = 1
        var state = try makeState(openMap, tanks: [
            tank(0, .player, .medium, 1, 1, hp: 5),
            tank(1, .ai, .medium, 3, 3, hp: 5),
        ], config: config)

        state = try Rules.apply(.pass, to: state).state
        state = try Rules.apply(.pass, to: state).state
        XCTAssertEqual(state.status, .finished(.draw))
    }

    func testDestroyedTanksCountAsZeroHPAtTheRoundLimit() throws {
        var config = GameConfig.phase1Default
        config.maxRounds = 1
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .medium, 1, 1, hp: 1),
            tank(1, .ai, .medium, 3, 3, hp: 10),
            tank(2, .ai, .medium, 3, 2, hp: 0),   // destroyed, contributes nothing
        ], config: config)

        XCTAssertEqual(state.totalHP(of: .player), 1)
        XCTAssertEqual(state.totalHP(of: .ai), 10)
        XCTAssertEqual(Rules.hpResult(in: state), .win(.ai, .moreHPAtRoundLimit))
    }

    func testAFullMatchOnTheRealMapStartsOngoing() throws {
        let state = try GameState.newGame(map: try GameMap(ascii: Maps.crossing))
        XCTAssertEqual(state.status, .ongoing)
        XCTAssertNil(Rules.annihilationResult(in: state))
        XCTAssertEqual(state.aliveTanks(of: .player).count, 5)
        XCTAssertEqual(state.aliveTanks(of: .ai).count, 5)
        // Every tank can do something on turn 1.
        for tank in state.aliveTanks(of: .player) {
            XCTAssertFalse(Rules.reachableTiles(for: tank, in: state).isEmpty)
        }
    }
}
