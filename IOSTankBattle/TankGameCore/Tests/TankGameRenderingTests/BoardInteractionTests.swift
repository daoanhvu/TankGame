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

    func testTappingAReachableTileMarksIt() throws {
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
        XCTAssertEqual(interaction.pathHint.last, p(3, 2), "The route to Tile1 is drawn instead")
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
        XCTAssertEqual(interaction.targetableTankIDs, [1], "Adjacent to Tile1, so it gets an X")
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
        interaction.tapTile(p(4, 2))          // Tile1, in range of the enemy
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
        XCTAssertNil(interaction.attackPreview)
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
        interaction.tapTile(p(4, 2))          // Tile1
        interaction.tapTile(p(5, 2))          // aim
        let events = interaction.tapAimedEnemyAgain()

        XCTAssertEqual(interaction.state.tanks[0].position, p(4, 2))
        XCTAssertEqual(interaction.state.tanks[1].hp, 6)
        XCTAssertEqual(interaction.state.tanks[0].hp, 6, "Took the counterattack")
        XCTAssertEqual(interaction.state.currentSide, .ai, "Turn handed over")
        XCTAssertEqual(interaction.phase, .idle, "Selection cleared after acting")

        // The renderer gets the move, the shot and the reply, in that order.
        // Fail rather than index past the end: an out-of-range index crashes
        // the whole test process, and every suite after this one never runs.
        guard events.count == 4 else { return XCTFail("Expected 4 events, got \(events)") }
        XCTAssertEqual(events[0], .moved(0, path: [p(1, 2), p(2, 2), p(3, 2), p(4, 2)]))
        XCTAssertEqual(events[1], .attacked(attacker: 0, defender: 1, damage: 4, destroyed: false))
        XCTAssertEqual(events[2], .counterattacked(attacker: 1, defender: 0, damage: 4, destroyed: false))
        XCTAssertEqual(events[3], .turnBegan(.ai, round: 1))
    }

    func testTappingTile1WhileAimingMovesWithoutFiring() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(4, 2))                  // Tile1
        interaction.tapTile(p(5, 2))                  // aim at it...
        XCTAssertNotNil(interaction.aimedTargetID)
        let events = interaction.tapTile1Again()      // ...then think better of it

        XCTAssertEqual(interaction.state.tanks[0].position, p(4, 2))
        XCTAssertEqual(interaction.state.tanks[1].hp, 10, "Nobody was shot")
        XCTAssertEqual(interaction.state.tanks[0].ammo, 5, "No ammo spent")
        XCTAssertEqual(interaction.state.currentSide, .ai)
        XCTAssertTrue(events.contains(.moved(0, path: [p(1, 2), p(2, 2), p(3, 2), p(4, 2)])))
    }

    func testTappingTheTankAgainHoldsPosition() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile1Again()

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
        interaction.tapAimedEnemyAgain()

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

    func testHotSeatLetsBothSidesPlayInTurn() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        // Blue drives up.
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(2, 2))
        interaction.tapTile1Again()
        XCTAssertEqual(interaction.currentSide, .ai)

        // Red answers on the same device.
        interaction.tapTile(p(5, 2))
        interaction.tapTile(p(4, 2))
        interaction.tapTile1Again()

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
        let events = interaction.tapAimedEnemyAgain()

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
        interaction.tapAimedEnemyAgain()

        interaction.tapTile(p(4, 2))
        XCTAssertEqual(interaction.phase, .idle, "No selecting after the final shot")
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
        interaction.tapAimedEnemyAgain()
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

/// The Tap-flow diagram in `docs/design.md`, branch by branch. Tile1 is the tile
/// the tank would act from: its own tile when selected, then whichever
/// reachable tile was tapped last. Every enemy in range of Tile1 gets an X.
final class BoardInteractionTapFlowTests: XCTestCase {

    // MARK: Selecting

    func testSelectingMarksEnemiesInRangeOfWhereItStands() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 3, 2),      // range 1-2
            tank(1, .ai, .light, 4, 2),           // in range
            tank(2, .ai, .light, 6, 4),           // not
        ])
        interaction.tapTile(p(3, 2))

        XCTAssertEqual(interaction.plan?.destination, p(3, 2), "Tile1 starts as its own tile")
        XCTAssertEqual(interaction.targetableTankIDs, [1], "Only the enemy in range gets an X")
    }

    // MARK: Tile1 is reachable

    func testTappingAReachableTileMakesItTile1AndMovesTheXsWithIt() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        XCTAssertTrue(interaction.targetableTankIDs.isEmpty, "4 away from where it stands")

        let events = interaction.tapTile(p(4, 2))

        XCTAssertTrue(events.isEmpty, "Choosing Tile1 commits nothing")
        XCTAssertEqual(interaction.plan?.destination, p(4, 2))
        XCTAssertEqual(interaction.targetableTankIDs, [1], "In range of Tile1, so it gets an X")
        XCTAssertEqual(interaction.state.tanks[0].position, p(1, 2), "The tank has not moved")
    }

    func testTappingTile1AgainMovesThereAndSpendsTheTank() throws {
        // "User tap on Tile1 → move the tank to Tile1 and end."
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .player, .light, 0, 0),
            tank(2, .ai, .medium, 5, 4),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(3, 2))
        let events = interaction.tapTile(p(3, 2))

        XCTAssertEqual(events, [.moved(0, path: [p(1, 2), p(2, 2), p(3, 2)])])
        XCTAssertEqual(interaction.state.tanks[0].position, p(3, 2))
        XCTAssertTrue(interaction.state.hasActed(0), "Its go is spent")
        XCTAssertEqual(interaction.phase, .idle, "Ready for the next tank")
        XCTAssertEqual(interaction.currentSide, .player, "The light still owes an action")
    }

    func testTappingTheTankAgainHoldsPosition() throws {
        // Tile1 is its own tile until another is chosen, so the same "tap
        // Tile1 again" that moves a tank is how it stays put.
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .player, .light, 0, 0),
            tank(2, .ai, .medium, 5, 4),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(1, 2))

        XCTAssertEqual(interaction.state.tanks[0].position, p(1, 2))
        XCTAssertTrue(interaction.state.hasActed(0))
        XCTAssertEqual(interaction.phase, .idle)
    }

    func testTappingTheTanksOwnTileAfterChoosingAnotherBringsTile1Home() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 4),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(3, 2))
        let events = interaction.tapTile(p(1, 2))

        XCTAssertTrue(events.isEmpty, "Moving Tile1 is not a commit")
        XCTAssertEqual(interaction.plan?.destination, p(1, 2))
        XCTAssertEqual(interaction.state.currentSide, .player)
    }

    // MARK: Enemies with an X

    func testTheFirstTapOnAnXOnlyShowsThePreview() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(4, 2))
        let events = interaction.tapTile(p(5, 2))

        XCTAssertTrue(events.isEmpty, "A preview, not a shot")
        XCTAssertEqual(interaction.aimedTargetID, 1)
        XCTAssertEqual(interaction.attackPreview?.damage, 4)
        XCTAssertEqual(interaction.state.tanks[1].hp, 10)
        XCTAssertEqual(interaction.state.tanks[0].position, p(1, 2), "Nor a move")
    }

    func testTheSecondTapOnTheSameEnemyMovesThenFires() throws {
        // "User taps on an enemy with X → move Tank1 to Tile1 and then attack."
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(4, 2))
        interaction.tapTile(p(5, 2))
        let events = interaction.tapTile(p(5, 2))

        XCTAssertEqual(events.first, .moved(0, path: [p(1, 2), p(2, 2), p(3, 2), p(4, 2)]),
                       "It drives first...")
        XCTAssertTrue(events.contains(.attacked(attacker: 0, defender: 1, damage: 4, destroyed: false)),
                      "...then fires")
        XCTAssertEqual(interaction.state.tanks[0].position, p(4, 2))
        XCTAssertEqual(interaction.state.tanks[1].hp, 6)
        XCTAssertNil(interaction.attackPreview, "The X's and the aim are gone")
    }

    func testTappingADifferentXSwitchesTheAimWithoutFiring() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 3, 2),
            tank(1, .ai, .light, 4, 2),
            tank(2, .ai, .light, 3, 3),
        ])
        interaction.tapTile(p(3, 2))
        interaction.tapTile(p(4, 2))
        let events = interaction.tapTile(p(3, 3))

        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(interaction.aimedTargetID, 2)
        XCTAssertEqual(interaction.state.tanks[1].hp, 6, "The first target was never fired on")
    }

    func testChoosingAnotherTile1DropsTheAim() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 3, 2),
            tank(1, .ai, .light, 4, 2),
        ])
        interaction.tapTile(p(3, 2))
        interaction.tapTile(p(4, 2))      // aim from where it stands
        interaction.tapTile(p(1, 2))      // then choose a different Tile1

        XCTAssertNil(interaction.aimedTargetID, "The aim was from the old Tile1")
        XCTAssertEqual(interaction.plan?.destination, p(1, 2))
    }

    func testAnEnemyWithoutAnXIsOnlyDescribed() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .ai, .medium, 5, 2),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(5, 2))      // out of range of Tile1

        XCTAssertNil(interaction.aimedTargetID)
        XCTAssertEqual(interaction.inspectedTankID, 1)
        XCTAssertEqual(interaction.selectedTankID, 0)
    }

    // MARK: Tile1 is not reachable

    func testTappingUnreachableGroundKeepsTheSelection() throws {
        // "Do nothing. The selected tank is still being selected."
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 0, 0),      // 3 move points
            tank(1, .ai, .medium, 6, 4),
        ])
        interaction.tapTile(p(0, 0))
        interaction.tapTile(p(2, 0))              // Tile1
        let planBefore = interaction.plan

        let events = interaction.tapTile(p(6, 0)) // 6 away: out of reach

        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(interaction.plan, planBefore, "Tile1 and the selection are untouched")
    }

    func testAnotherFriendlyTankIsNotReachableEither() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .medium, 1, 2),
            tank(1, .player, .light, 2, 2),
            tank(2, .ai, .medium, 6, 4),
        ])
        interaction.tapTile(p(1, 2))
        interaction.tapTile(p(2, 2))              // occupied by a friend

        XCTAssertEqual(interaction.selectedTankID, 0, "Cancel is how to switch tanks")
        XCTAssertEqual(interaction.plan?.destination, p(1, 2))
        XCTAssertEqual(interaction.state.currentSide, .player)
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
        interaction.tapTile(p(0, 3))          // Tile1
        interaction.tapTile(p(0, 3))          // again: move there

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
        interaction.tapTile1Again()
        interaction.tapTile(p(1, 4))
        interaction.tapTile1Again()

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
        interaction.tapTile1Again()

        interaction.tapTile(p(0, 4))          // tap the tank that already moved
        XCTAssertNil(interaction.selectedTankID, "Its go is spent")
        XCTAssertEqual(interaction.inspectedTankID, 0, "...but the HUD still describes it")
        XCTAssertNil(interaction.plan)
    }

    func testPassGivesUpTheRestOfTheTurn() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 0, 4),
            tank(1, .player, .medium, 1, 4),
            tank(2, .ai, .medium, 6, 0),
        ])
        interaction.tapTile(p(0, 4))
        interaction.tapTile1Again()
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
        XCTAssertNotNil(interaction.attackPreview)
        interaction.tapAimedEnemyAgain()

        XCTAssertFalse(interaction.state.tanks[2].isAlive, "Target destroyed")
        XCTAssertEqual(interaction.currentSide, .player, "The light still owes an action")
        XCTAssertEqual(interaction.pendingTankIDs, [1])
    }
}
