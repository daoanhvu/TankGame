import XCTest
@testable import TankGameRendering
@testable import TankGameCore

/// A 7x5 open board. Supplies at (0,0) for Blue and (6,4) for Red.
///
///     S.....a
///     .......
///     .......
///     .......
///     P.....s
private let testMap = """
    S.....a
    .......
    .......
    .......
    P.....s
    """

private func p(_ x: Int, _ y: Int) -> Position { Position(x: x, y: y) }

private func tank(_ id: TankID, _ side: Side, _ kind: TankKind, _ x: Int, _ y: Int,
                  hp: Int? = nil, ammo: Int? = nil) -> Tank {
    let stats = GameConfig.phase1Default.stats(for: kind)
    return Tank(id: id, side: side, kind: kind, position: p(x, y),
                hp: hp ?? stats.maxHP, ammo: ammo ?? stats.maxAmmo)
}

private func makeInteraction(_ tanks: [Tank],
                             currentSide: Side = .player,
                             config: GameConfig = .phase1Default) throws -> BoardInteraction {
    let state = GameState(config: config, map: try GameMap(ascii: testMap), tanks: tanks,
                          currentSide: currentSide, round: 1, status: .ongoing)
    return BoardInteraction(state: state)
}

final class BoardInteractionSelectionTests: XCTestCase {

    func testStartsIdleWithNothingHighlighted() throws {
        let interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        XCTAssertEqual(interaction.phase, .idle)
        XCTAssertNil(interaction.selectedTankID)
        XCTAssertTrue(interaction.moveHighlights.isEmpty)
        XCTAssertTrue(interaction.targetableTankIDs.isEmpty)
        XCTAssertFalse(interaction.canWait)
        XCTAssertFalse(interaction.canAttack)
        XCTAssertTrue(interaction.canPass)
    }

    func testTappingYourTankSelectsItAndShowsItsMoves() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),      // 3 move points
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))

        XCTAssertEqual(interaction.selectedTankID, 0)
        XCTAssertEqual(interaction.plan?.destination, p(1, 2), "Not moved yet")
        XCTAssertFalse(interaction.plan?.hasMoved ?? true)
        XCTAssertTrue(interaction.canWait, "A selected tank can always just wait")
        XCTAssertFalse(interaction.moveHighlights.contains(p(1, 2)),
                       "The tank's own tile is not drawn as a move option")
        XCTAssertTrue(interaction.moveHighlights.contains(p(4, 2)), "3 tiles away, within budget")
        XCTAssertFalse(interaction.moveHighlights.contains(p(5, 2)), "Occupied by the enemy")
    }

    func testTappingAnEnemyTankSelectsNothing() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(5, 2))
        XCTAssertEqual(interaction.phase, .idle, "You may only drive your own tanks")
    }

    func testOnlyTheSideToMoveCanSelect() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ], currentSide: .ai)

        interaction.tapTile(p(1, 2))
        XCTAssertEqual(interaction.phase, .idle, "Blue cannot act on Red's turn")

        interaction.tapTile(p(5, 2))
        XCTAssertEqual(interaction.selectedTankID, 1, "Red is up, so Red's tank selects")
    }

    func testTappingAnotherFriendlyTankDoesNotSwitchSelection() throws {
        // Switching tanks goes through Cancel now, so a stray tap on a friend
        // cannot throw away a move you were planning.
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .player, .light, 3, 4),
            tank(2, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(3, 4))
        XCTAssertEqual(interaction.selectedTankID, 0, "Still the tank we picked")
        XCTAssertEqual(interaction.plan?.origin, p(1, 2))
    }

    func testCancelThenTapSelectsADifferentTank() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .player, .light, 3, 4),
            tank(2, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        interaction.cancel()
        interaction.tapTile(p(3, 4))
        XCTAssertEqual(interaction.selectedTankID, 1)
    }

    func testTappingOutOfReachGroundIsIgnored() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .artillery, 1, 2),   // only 2 move points
            tank(1, .ai, .medium, 5, 0),
        ])
        interaction.tapTile(p(1, 2))
        XCTAssertNotNil(interaction.selectedTankID)

        interaction.tapTile(p(5, 4))
        XCTAssertEqual(interaction.selectedTankID, 0,
                       "A tap on unreachable ground must not drop the selection")
    }

    func testDestroyedTanksCannotBeSelected() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2, hp: 0),
            tank(1, .player, .medium, 2, 2),
            tank(2, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        XCTAssertEqual(interaction.phase, .idle)
    }
}

final class BoardInteractionPlanningTests: XCTestCase {

    func testTappingAReachableTileRepointsTheMove() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(3, 2))

        XCTAssertEqual(interaction.plan?.destination, p(3, 2))
        XCTAssertTrue(interaction.plan?.hasMoved ?? false)
        XCTAssertEqual(interaction.state.tanks[0].position, p(1, 2),
                       "Planning must not move the real tank")
        XCTAssertEqual(interaction.plannedPath.first, p(1, 2))
        XCTAssertEqual(interaction.plannedPath.last, p(3, 2))
    }

    func testMovingChangesWhichEnemiesAreInRange() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 1, 2),       // range 1, 5 move points
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        XCTAssertTrue(interaction.targetableTankIDs.isEmpty, "4 tiles away, out of range")

        interaction.tapTile(p(4, 2))
        XCTAssertEqual(interaction.targetableTankIDs, [1], "Adjacent after the planned move")
    }

    func testTappingYourOwnTileAgainCancelsThePlannedMove() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(3, 2))
        interaction.tapTile(p(1, 2))

        XCTAssertEqual(interaction.plan?.destination, p(1, 2))
        XCTAssertTrue(interaction.plannedPath.isEmpty)
    }

    func testADryTankPlanningOntoItsSupplyTileCanStillShoot() throws {
        // Out of ammo at (1,0), one step from the Blue supply tile at (0,0),
        // with a Red tank adjacent to that supply tile.
        var interaction = try makeInteraction([
            tank(0, .player, .light, 1, 0, ammo: 0),
            tank(1, .ai, .light, 0, 1),
        ])
        interaction.tapTile(p(1, 0))
        XCTAssertTrue(interaction.targetableTankIDs.isEmpty, "No ammo where it stands")

        interaction.tapTile(p(0, 0))
        XCTAssertEqual(interaction.targetableTankIDs, [1],
                       "Driving onto the supply tile rearms it, so the shot is on")
    }

    func testCancelDropsTheWholeSelectionInOneTap() throws {
        // Cancel is the only way out now, so it goes all the way rather than
        // stepping back a stage at a time.
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 4, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(4, 2))
        interaction.tapTile(p(5, 2))
        XCTAssertNotNil(interaction.aimedTargetID)

        interaction.cancel()
        XCTAssertEqual(interaction.phase, .idle)
        XCTAssertNil(interaction.selectedTankID)
        XCTAssertEqual(interaction.state.tanks[0].position, p(4, 2), "Nothing was committed")
    }
}

final class BoardInteractionAimingTests: XCTestCase {

    func testAimingAtAnEnemyShowsTheDamagePreview() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 4, 2),      // damage 4, range 1-2
            tank(1, .ai, .medium, 5, 2),          // damage 4, range 1-2
        ])
        interaction.tapTile(p(4, 2))
        interaction.tapTile(p(5, 2))

        let preview = try XCTUnwrap(interaction.attackPreview)
        XCTAssertEqual(interaction.aimedTargetID, 1)
        XCTAssertEqual(preview.damage, 4)
        XCTAssertFalse(preview.targetDestroyed)
        XCTAssertEqual(preview.counterDamage, 4, "Both are mediums, so it fires back")
        XCTAssertTrue(interaction.canAttack)
    }

    func testPreviewWarnsWhenTheCounterattackWouldKillYou() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 4, 2, hp: 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(4, 2))
        interaction.tapTile(p(5, 2))

        let preview = try XCTUnwrap(interaction.attackPreview)
        XCTAssertTrue(preview.attackerDestroyed)
    }

    func testPreviewReportsNoCounterattackOutOfTheDefendersRange() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .artillery, 1, 2),   // range 2-4, damage 5
            tank(1, .ai, .light, 4, 2),           // range 1 only
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(4, 2))

        let preview = try XCTUnwrap(interaction.attackPreview)
        XCTAssertEqual(preview.damage, 5)
        XCTAssertFalse(preview.hasCounterattack)
    }

    func testThePreviewAccountsForThePlannedMove() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2, hp: 3),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(4, 2))          // plan a move into range
        interaction.tapTile(p(5, 2))          // then aim

        let preview = try XCTUnwrap(interaction.attackPreview)
        XCTAssertEqual(preview.counterDamage, 3, "Capped at our remaining HP")
        XCTAssertTrue(preview.attackerDestroyed)
    }

    func testAimingAtAnEnemyOutOfRangeIsIgnored() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 1, 2),
            tank(1, .ai, .medium, 5, 4),          // too far even after moving
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(5, 4))

        XCTAssertNil(interaction.aimedTargetID)
        XCTAssertFalse(interaction.canAttack)
        XCTAssertEqual(interaction.selectedTankID, 0, "The selection survives a bad tap")
    }

    func testRepointingTheMoveDropsTheAim() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 4, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(4, 2))
        interaction.tapTile(p(5, 2))
        XCTAssertNotNil(interaction.aimedTargetID)

        interaction.tapTile(p(4, 4))
        XCTAssertNil(interaction.aimedTargetID, "Range depends on where we stop, so the aim resets")
        XCTAssertEqual(interaction.plan?.destination, p(4, 4))
    }
}

final class BoardInteractionCommitTests: XCTestCase {

    func testAttackAppliesDamageAndEndsTheTurn() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(4, 2))
        interaction.tapTile(p(5, 2))
        let events = interaction.attack()

        XCTAssertEqual(interaction.state.tanks[0].position, p(4, 2))
        XCTAssertEqual(interaction.state.tanks[1].hp, 6)
        XCTAssertEqual(interaction.state.tanks[0].hp, 6, "Took the counterattack")
        XCTAssertEqual(interaction.state.currentSide, .ai, "Turn handed over")
        XCTAssertEqual(interaction.phase, .idle, "Selection cleared after acting")

        // The renderer gets the move, the shot and the reply, in that order.
        XCTAssertEqual(events.count, 4)
        XCTAssertEqual(events[0], .moved(0, path: [p(1, 2), p(2, 2), p(3, 2), p(4, 2)]))
        XCTAssertEqual(events[1], .attacked(attacker: 0, defender: 1, damage: 4, destroyed: false))
        XCTAssertEqual(events[2], .counterattacked(attacker: 1, defender: 0, damage: 4, destroyed: false))
        XCTAssertEqual(events[3], .turnBegan(.ai, round: 1))
    }

    func testWaitMovesWithoutFiring() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(4, 2))
        interaction.tapTile(p(5, 2))       // aim at it...
        let events = interaction.wait()    // ...then think better of it

        XCTAssertEqual(interaction.state.tanks[0].position, p(4, 2))
        XCTAssertEqual(interaction.state.tanks[1].hp, 10, "Nobody was shot")
        XCTAssertEqual(interaction.state.tanks[0].ammo, 5, "No ammo spent")
        XCTAssertEqual(interaction.state.currentSide, .ai)
        XCTAssertTrue(events.contains(.moved(0, path: [p(1, 2), p(2, 2), p(3, 2), p(4, 2)])))
    }

    func testWaitWithoutMovingStillEndsTheTurn() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        interaction.wait()

        XCTAssertEqual(interaction.state.tanks[0].position, p(1, 2))
        XCTAssertEqual(interaction.state.currentSide, .ai)
    }

    func testAttackWithoutMovingIsAllowed() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 4, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(4, 2))
        interaction.tapTile(p(5, 2))
        interaction.attack()

        XCTAssertEqual(interaction.state.tanks[0].position, p(4, 2), "Stayed put")
        XCTAssertEqual(interaction.state.tanks[1].hp, 6)
    }

    func testPassHandsOverTheTurnAndCountsTheRound() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.pass()
        XCTAssertEqual(interaction.state.currentSide, .ai)
        XCTAssertEqual(interaction.state.round, 1)

        interaction.pass()
        XCTAssertEqual(interaction.state.currentSide, .player)
        XCTAssertEqual(interaction.state.round, 2, "Both sides have now acted")
    }

    func testPassClearsAnyHalfFinishedSelection() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 4, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(4, 2))
        interaction.tapTile(p(5, 2))
        interaction.pass()

        XCTAssertEqual(interaction.phase, .idle)
        XCTAssertEqual(interaction.state.tanks[1].hp, 10, "Passing fires nothing")
    }

    func testAttackIsIgnoredWithoutATarget() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        XCTAssertTrue(interaction.attack().isEmpty)
        XCTAssertEqual(interaction.state.currentSide, .player, "Nothing happened")
    }

    func testHotSeatLetsBothSidesPlayInTurn() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        // Blue drives up.
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(2, 2))
        interaction.wait()
        XCTAssertEqual(interaction.currentSide, .ai)

        // Red answers on the same device.
        interaction.tapTile(p(5, 2))
        interaction.tapTile(p(4, 2))
        interaction.wait()

        XCTAssertEqual(interaction.state.tanks[0].position, p(2, 2))
        XCTAssertEqual(interaction.state.tanks[1].position, p(4, 2))
        XCTAssertEqual(interaction.state.round, 2)
    }
}

final class BoardInteractionEndOfMatchTests: XCTestCase {

    func testKillingTheLastEnemyEndsTheMatch() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 4, 2),
            tank(1, .ai, .light, 5, 2, hp: 1, ammo: 0),
        ])
        interaction.tapTile(p(4, 2))
        interaction.tapTile(p(5, 2))
        let events = interaction.attack()

        XCTAssertEqual(interaction.state.status, .finished(.win(.player, .annihilation)))
        XCTAssertTrue(interaction.isOver)
        XCTAssertTrue(events.contains(.gameEnded(.win(.player, .annihilation))))
    }

    func testEverythingIsLockedOutOnceTheMatchIsOver() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 4, 2),
            tank(1, .ai, .light, 5, 2, hp: 1, ammo: 0),
        ])
        interaction.tapTile(p(4, 2))
        interaction.tapTile(p(5, 2))
        interaction.attack()

        interaction.tapTile(p(4, 2))
        XCTAssertEqual(interaction.phase, .idle, "No selecting after the final shot")
        XCTAssertFalse(interaction.canWait)
        XCTAssertFalse(interaction.canAttack)
        XCTAssertFalse(interaction.canPass)
        XCTAssertTrue(interaction.pass().isEmpty)
    }

    func testResetStartsAFreshMatch() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 4, 2),
            tank(1, .ai, .light, 5, 2, hp: 1, ammo: 0),
        ])
        interaction.tapTile(p(4, 2))
        interaction.tapTile(p(5, 2))
        interaction.attack()
        XCTAssertTrue(interaction.isOver)

        let fresh = try GameState.newGame(map: try GameMap(ascii: Maps.crossing))
        interaction.reset(to: fresh)

        XCTAssertFalse(interaction.isOver)
        XCTAssertEqual(interaction.phase, .idle)
        XCTAssertEqual(interaction.currentSide, .player)
        XCTAssertEqual(interaction.state.round, 1)
    }

    func testTheRoundLimitEndsTheMatchOnHP() throws {
        var config = GameConfig.phase1Default
        config.maxRounds = 1
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2, hp: 9),
            tank(1, .ai, .medium, 5, 2, hp: 4),
        ], config: config)

        interaction.pass()
        interaction.pass()
        XCTAssertEqual(interaction.state.status, .finished(.win(.player, .moreHPAtRoundLimit)))
    }
}

/// The confirmation tap: a planned move only becomes real when the player taps
/// the destination a second time, so a turn is never spent by accident.
final class BoardInteractionConfirmationTests: XCTestCase {

    func testTappingTheDestinationAgainCommitsTheMove() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 4),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(3, 2))

        XCTAssertEqual(interaction.state.tanks[0].position, p(1, 2),
                       "First tap only plans the move")
        XCTAssertEqual(interaction.state.currentSide, .player, "...and does not spend the turn")

        let events = interaction.tapTile(p(3, 2))      // the confirmation

        XCTAssertEqual(interaction.state.tanks[0].position, p(3, 2), "Second tap commits it")
        XCTAssertEqual(interaction.state.currentSide, .ai, "The turn is over")
        XCTAssertEqual(interaction.phase, .idle)
        XCTAssertTrue(events.contains(.moved(0, path: [p(1, 2), p(2, 2), p(3, 2)])))
    }

    func testConfirmingCommitsAMoveOnlyAction() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 4, 2),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(3, 2))      // ends up adjacent to the enemy
        interaction.tapTile(p(3, 2))      // confirm

        XCTAssertEqual(interaction.state.tanks[1].hp, 10, "Confirming a move fires nothing")
        XCTAssertEqual(interaction.state.tanks[0].ammo, 5)
    }

    func testTappingADifferentTileRepointsInsteadOfConfirming() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 4),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(3, 2))
        let events = interaction.tapTile(p(1, 3))      // a different reachable tile

        XCTAssertTrue(events.isEmpty, "Re-pointing commits nothing")
        XCTAssertEqual(interaction.plan?.destination, p(1, 3))
        XCTAssertEqual(interaction.state.currentSide, .player, "Still our turn")
    }

    func testConfirmingTheNewTileAfterRepointingCommitsThatOne() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 4),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(3, 2))
        interaction.tapTile(p(1, 3))
        interaction.tapTile(p(1, 3))

        XCTAssertEqual(interaction.state.tanks[0].position, p(1, 3))
        XCTAssertEqual(interaction.state.currentSide, .ai)
    }

    func testTappingAnUnmovedTankTwiceDoesNotSpendTheTurn() throws {
        // Double-tapping a tank you just picked is far more likely to be a slip
        // than a deliberate "stand still and do nothing". Wait exists for that.
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 4),
        ])
        interaction.tapTile(p(1, 2))
        let events = interaction.tapTile(p(1, 2))

        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(interaction.state.currentSide, .player)
        XCTAssertEqual(interaction.selectedTankID, 0, "Still selected, still waiting")
    }

    func testMoveThenAttackStillWorksWithoutConfirming() throws {
        // The confirmation tap is for ending the turn on a move. Attacking after
        // a move goes through the target instead, so both stay one tap.
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(4, 2))      // drive into range
        interaction.tapTile(p(5, 2))      // aim at the enemy
        XCTAssertNotNil(interaction.attackPreview)

        interaction.attack()

        XCTAssertEqual(interaction.state.tanks[0].position, p(4, 2), "It moved")
        XCTAssertEqual(interaction.state.tanks[1].hp, 6, "...and fired in the same turn")
    }

    func testConfirmingWhileAimingCommitsTheMoveAndDropsTheShot() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(4, 2))
        interaction.tapTile(p(5, 2))      // aimed
        interaction.tapTile(p(4, 2))      // confirm the move instead

        XCTAssertEqual(interaction.state.tanks[0].position, p(4, 2))
        XCTAssertEqual(interaction.state.tanks[1].hp, 10, "The shot was never taken")
        XCTAssertEqual(interaction.state.currentSide, .ai)
    }

    func testWaitStillEndsTheTurnWithoutAConfirmationTap() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 4),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(3, 2))
        interaction.wait()

        XCTAssertEqual(interaction.state.tanks[0].position, p(3, 2))
        XCTAssertEqual(interaction.state.currentSide, .ai)
    }
}

/// Inspection (`docs/sprite_design.md` D2a): both sides wear one hull per side,
/// so the HUD has to say what a tank is — which means every tap on a tank has
/// to name it, including the ones that used to be swallowed.
final class BoardInteractionInspectionTests: XCTestCase {

    func testTappingAnOutOfRangeEnemyInspectsItWithoutDisturbingThePlan() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 0, 4),
            tank(1, .ai, .medium, 6, 0),       // far away, not targetable
        ])
        interaction.tapTile(p(0, 4))
        let planBefore = interaction.plan

        interaction.tapTile(p(6, 0))

        XCTAssertEqual(interaction.inspectedTankID, 1)
        XCTAssertEqual(interaction.plan, planBefore, "inspecting must not re-point the move")
        XCTAssertNil(interaction.aimedTargetID)
    }

    /// The regression that would quietly break attacking: an enemy in range
    /// must still aim, not merely get looked at.
    func testTappingAnEnemyInRangeStillAims() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 3, 2),
            tank(1, .ai, .light, 4, 2),        // adjacent, in range
        ])
        interaction.tapTile(p(3, 2))
        interaction.tapTile(p(4, 2))

        XCTAssertEqual(interaction.aimedTargetID, 1)
        XCTAssertEqual(interaction.describedTankID, 1)
    }

    func testTappingAnEnemyFromIdleInspectsIt() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 0, 4),
            tank(1, .ai, .artillery, 6, 0),
        ])
        interaction.tapTile(p(6, 0))

        XCTAssertEqual(interaction.inspectedTankID, 1)
        XCTAssertEqual(interaction.describedTankID, 1)
        XCTAssertNil(interaction.selectedTankID, "an enemy is never selectable")
    }

    func testDescribedTankPrefersAimedThenSelectedThenInspected() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 3, 2),
            tank(1, .ai, .light, 4, 2),
            tank(2, .ai, .medium, 6, 0),
        ])
        XCTAssertNil(interaction.describedTankID)

        interaction.tapTile(p(3, 2))                    // select our own
        XCTAssertEqual(interaction.describedTankID, 0)

        // Inspecting beats the selection: this is the whole point of it.
        interaction.tapTile(p(6, 0))
        XCTAssertEqual(interaction.describedTankID, 2)
        XCTAssertEqual(interaction.selectedTankID, 0, "the tank stays selected")

        // Aiming beats both.
        interaction.tapTile(p(4, 2))
        XCTAssertEqual(interaction.describedTankID, 1)
    }

    func testMovingTheSelectedTankStopsDescribingTheInspectedOne() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 3, 2),
            tank(1, .ai, .medium, 6, 0),
        ])
        interaction.tapTile(p(3, 2))
        interaction.tapTile(p(6, 0))
        XCTAssertEqual(interaction.describedTankID, 1)

        interaction.tapTile(p(3, 3))                    // re-point the move
        XCTAssertNil(interaction.inspectedTankID)
        XCTAssertEqual(interaction.describedTankID, 0)
    }

    func testSelectingAndCancellingClearTheInspection() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 0, 4),
            tank(1, .ai, .medium, 6, 0),
        ])
        interaction.tapTile(p(6, 0))
        XCTAssertEqual(interaction.inspectedTankID, 1)

        interaction.tapTile(p(0, 4))
        XCTAssertNil(interaction.inspectedTankID, "selecting replaces what is described")

        interaction.tapTile(p(6, 0))
        interaction.cancel()
        XCTAssertNil(interaction.inspectedTankID)
        XCTAssertNil(interaction.describedTankID)
    }

    func testEndingTheTurnClearsTheInspection() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 0, 4),
            tank(1, .ai, .medium, 6, 0),
        ])
        interaction.tapTile(p(6, 0))
        interaction.pass()
        XCTAssertNil(interaction.inspectedTankID)
    }

    func testInspectingATankThatIsNotTheCurrentSides() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 0, 4),
            tank(1, .ai, .medium, 6, 0),
        ], currentSide: .ai)
        // Blue's tank, Red's turn: not selectable, but still worth describing.
        interaction.tapTile(p(0, 4))
        XCTAssertEqual(interaction.inspectedTankID, 0)
        XCTAssertNil(interaction.selectedTankID)
    }
}


/// A turn is one action per tank, so committing one tank's orders no longer
/// ends the side's turn — the board has to stay with the player until every
/// tank has had its go or they pass.
final class BoardInteractionTurnTests: XCTestCase {

    func testCommittingOneTankLeavesTheTurnWithThePlayer() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 0, 4),
            tank(1, .player, .medium, 1, 4),
            tank(2, .ai, .medium, 6, 0),
        ])
        XCTAssertEqual(interaction.pendingTankIDs, [0, 1])

        interaction.tapTile(p(0, 4))          // select
        interaction.tapTile(p(0, 3))          // point the move
        interaction.wait()                    // commit

        XCTAssertEqual(interaction.currentSide, .player, "Still Blue's turn")
        XCTAssertTrue(interaction.acceptsInput)
        XCTAssertEqual(interaction.pendingTankIDs, [1], "One tank left to command")
        XCTAssertEqual(interaction.phase, .idle, "...and nothing selected, ready for the next")
    }

    func testTheSecondTankEndsTheTurn() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 0, 4),
            tank(1, .player, .medium, 1, 4),
            tank(2, .ai, .medium, 6, 0),
        ])
        interaction.tapTile(p(0, 4))
        interaction.wait()
        interaction.tapTile(p(1, 4))
        interaction.wait()

        XCTAssertEqual(interaction.currentSide, .ai)
        XCTAssertTrue(interaction.pendingTankIDs.isEmpty == false, "Red's tanks are pending now")
        XCTAssertEqual(interaction.pendingTankIDs, [2])
    }

    func testASpentTankCannotBeSelectedButCanStillBeInspected() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 0, 4),
            tank(1, .player, .medium, 1, 4),
            tank(2, .ai, .medium, 6, 0),
        ])
        interaction.tapTile(p(0, 4))
        interaction.wait()

        interaction.tapTile(p(0, 4))          // tap the tank that already moved
        XCTAssertNil(interaction.selectedTankID, "Its go is spent")
        XCTAssertEqual(interaction.inspectedTankID, 0, "...but the HUD still describes it")
        XCTAssertFalse(interaction.canWait)
    }

    func testPassGivesUpTheRestOfTheTurn() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 0, 4),
            tank(1, .player, .medium, 1, 4),
            tank(2, .ai, .medium, 6, 0),
        ])
        interaction.tapTile(p(0, 4))
        interaction.wait()
        XCTAssertTrue(interaction.canPass)

        interaction.pass()
        XCTAssertEqual(interaction.currentSide, .ai)
        XCTAssertEqual(interaction.state.tanks[1].position, p(1, 4), "The unused tank stayed put")
    }

    func testAttackingSpendsTheTankButNotTheTurn() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 5, 0),
            tank(1, .player, .light, 0, 4),
            tank(2, .ai, .medium, 6, 0, hp: 4),
        ])
        interaction.tapTile(p(5, 0))          // select
        interaction.tapTile(p(6, 0))          // aim at the enemy
        XCTAssertTrue(interaction.canAttack)
        interaction.attack()

        XCTAssertFalse(interaction.state.tanks[2].isAlive, "Target destroyed")
        XCTAssertEqual(interaction.currentSide, .player, "The light still owes an action")
        XCTAssertEqual(interaction.pendingTankIDs, [1])
    }
}
