import XCTest
import TankGameCore
@testable import TankGameAI

// MARK: - Test helpers

/// Builds a state from an ASCII map and an explicit tank list, so each test
/// sets up the exact board it cares about. Mirrors the helper in RulesTests.
private func makeState(_ ascii: String,
                       tanks: [Tank],
                       config: GameConfig = .phase1Default,
                       currentSide: Side = .player,
                       round: Int = 1,
                       status: GameStatus = .ongoing) throws -> GameState {
    GameState(config: config, map: try GameMap(ascii: ascii), tanks: tanks,
              currentSide: currentSide, round: round, status: status)
}

private func tank(_ id: TankID, _ side: Side, _ kind: TankKind, _ x: Int, _ y: Int,
                  hp: Int? = nil, ammo: Int? = nil,
                  config: GameConfig = .phase1Default) -> Tank {
    let stats = config.stats(for: kind)
    return Tank(id: id, side: side, kind: kind, position: Position(x: x, y: y),
                hp: hp ?? stats.maxHP, ammo: ammo ?? stats.maxAmmo)
}

private func p(_ x: Int, _ y: Int) -> Position { Position(x: x, y: y) }

/// 9x9 open board. Player supply top-left, AI supply bottom-right, one spawn
/// each in the other two corners. Wide enough that a light tank's 5 move points
/// do not run into a wall.
private let openMap = """
    S.......a
    .........
    .........
    .........
    .........
    .........
    .........
    .........
    P.......s
    """

/// 5x5 with a wall of water across the middle, open at both ends. A tank at
/// (2,0) and one at (2,2) are 2 tiles apart as the crow flies and 6 to drive.
/// Both depots sit on the bottom row, well clear of the detour.
///
///     ..a..
///     .WWW.
///     .....
///     .....
///     PS.sa
private let dammedMap = """
    ..a..
    .WWW.
    .....
    .....
    PS.sa
    """

/// The command the AI chose, or nil if it passed.
private func chosenCommand(_ action: Action) -> TankCommand? {
    if case .command(let command) = action { return command }
    return nil
}

/// Scores one specific command, for tests that compare two options rather than
/// asserting what the whole brain picks.
private func score(_ command: TankCommand,
                   in state: GameState,
                   weights: AIWeights = .standard) -> ActionScore {
    let candidate = ActionGenerator.candidates(in: state).first {
        $0.action == .command(command)
    }
    guard let candidate else {
        XCTFail("\(command) is not a legal candidate")
        return ActionScore()
    }
    return GreedyEvaluator(weights: weights).score(candidate, in: state)
}

/// Never does anything. The baseline an opponent has to be able to beat.
private struct PassiveAI: TankAI {
    let name = "Passive"
    func chooseAction(in state: GameState) -> Action { .pass }
}

// MARK: - Candidate generation

final class ActionGeneratorTests: XCTestCase {

    func testEveryCandidateIsLegal() throws {
        // A crowded board: tanks of every kind, both sides, in and out of range.
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 3, 4),
            tank(1, .player, .medium, 4, 5),
            tank(2, .player, .artillery, 2, 6),
            tank(3, .ai, .light, 4, 4),
            tank(4, .ai, .medium, 6, 4),
            tank(5, .ai, .artillery, 7, 7),
        ])

        let candidates = ActionGenerator.candidates(in: state)
        XCTAssertFalse(candidates.isEmpty)
        for candidate in candidates {
            XCTAssertNoThrow(try Rules.apply(candidate.action, to: state),
                             "The rules rejected \(candidate.action)")
        }
    }

    func testOffersPassAndOnlyTheSideToMove() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 1, 1),
            tank(1, .ai, .light, 7, 7),
        ], currentSide: .ai)

        let candidates = ActionGenerator.candidates(in: state)
        XCTAssertTrue(candidates.contains { $0.action == .pass })
        XCTAssertTrue(candidates.compactMap { $0.tank?.id }.allSatisfy { $0 == 1 },
                      "Only the side to move may be commanded")
        XCTAssertFalse(ActionGenerator.candidates(in: state, includePass: false)
            .contains { $0.action == .pass })
    }

    func testOffersMoveThenShootFromTheDestination() throws {
        // The medium (range 1-2, 3 move points) cannot hit anything from (1,4),
        // but can after closing in.
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .medium, 1, 4),
            tank(1, .ai, .light, 6, 4),
        ])

        XCTAssertTrue(Rules.attackableTargets(for: state.tanks[0], in: state).isEmpty)
        let shots = ActionGenerator.candidates(in: state).filter { $0.target != nil }
        XCTAssertEqual(shots.map(\.destination), [p(4, 4)],
                       "Only the tile 2 away is both reachable and in range")
    }

    func testIgnoresDestroyedTanks() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 1, 1, hp: 0),
            tank(1, .player, .light, 2, 2),
            tank(2, .ai, .light, 7, 7),
        ])
        XCTAssertTrue(ActionGenerator.candidates(in: state).compactMap { $0.tank?.id }
            .allSatisfy { $0 == 1 })
    }

    func testOrderIsStableAcrossRuns() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 3, 3),
            tank(1, .player, .medium, 5, 5),
            tank(2, .ai, .light, 4, 3),
        ])
        let first = ActionGenerator.candidates(in: state).map(\.action)
        for _ in 0..<5 {
            XCTAssertEqual(ActionGenerator.candidates(in: state).map(\.action), first,
                           "Candidate order must not depend on dictionary hashing")
        }
    }

    func testNoCandidatesOnceTheMatchIsOver() throws {
        let state = try makeState(openMap, tanks: [tank(0, .player, .light, 1, 1)],
                                  status: .finished(.draw))
        XCTAssertTrue(ActionGenerator.candidates(in: state).isEmpty)
    }
}

// MARK: - Distance field

final class DistanceFieldTests: XCTestCase {

    func testCostsFollowTerrain() throws {
        let map = """
            S.T.a
            .....
            .....
            .....
            P...s
            """
        let state = try makeState(map, tanks: [
            tank(0, .player, .light, 0, 4),
            tank(1, .ai, .light, 4, 4),
        ])
        let field = DistanceField(to: [p(1, 0)], movingAs: .player, in: state)

        XCTAssertEqual(field.cost(at: p(1, 0)), 0)
        XCTAssertEqual(field.cost(at: p(0, 0)), 1)
        XCTAssertEqual(field.cost(at: p(2, 0)), 2, "Trees cost 2 to enter")
        XCTAssertEqual(field.cost(at: p(3, 0)), 3, "Round the trees, not through them")
    }

    func testRoutesAroundWaterInsteadOfThroughIt() throws {
        let state = try makeState(dammedMap, tanks: [
            tank(0, .player, .medium, 2, 2),
            tank(1, .ai, .medium, 2, 0),
        ])
        let field = DistanceField(to: [p(2, 2)], movingAs: .ai, in: state)

        XCTAssertEqual(p(2, 0).manhattanDistance(to: p(2, 2)), 2, "2 tiles as the crow flies")
        XCTAssertEqual(field.cost(at: p(2, 0)), 6, "...and 6 to drive, round the dam")
        // The gradient the approach term follows: towards either end of the wall.
        XCTAssertEqual(field.cost(at: p(0, 0)), 4)
        XCTAssertEqual(field.cost(at: p(4, 0)), 4)
        XCTAssertNil(field.cost(at: p(2, 1)), "The water itself is no route")
    }

    func testTilesWithNoRouteHaveNoCostAndNoGradient() throws {
        let pocket = """
            S.a..
            .RRR.
            .R.R.
            .RRR.
            P...s
            """
        let state = try makeState(pocket, tanks: [
            tank(0, .player, .light, 2, 2),
            tank(1, .ai, .light, 2, 0),
        ])
        let field = DistanceField(to: [p(2, 0)], movingAs: .player, in: state)

        XCTAssertNil(field.cost(at: p(2, 2)), "Walled in")
        XCTAssertEqual(field.progress(from: p(2, 2), to: p(2, 2)), 0,
                       "No route means no gradient to follow, not a huge penalty")
    }

    func testTheEnemyDepotIsNotAShortcut() throws {
        // (4,4) is Red's supply tile, which Blue may not drive onto.
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 0),
            tank(1, .ai, .light, 8, 8),
        ])
        let blueView = DistanceField(to: [p(8, 8)], movingAs: .player, in: state)
        let redView = DistanceField(to: [p(8, 8)], movingAs: .ai, in: state)

        XCTAssertNil(blueView.cost(at: p(8, 8)), "Red's depot is a hole in Blue's map")
        XCTAssertEqual(redView.cost(at: p(8, 8)), 0)
    }
}

// MARK: - Threat map

final class ThreatMapTests: XCTestCase {

    func testCoversWhereAnEnemyCouldDriveAndShoot() throws {
        // AI medium at (8,4): 3 move points, range 1-2, so it covers everything
        // within 5 tiles of its position... but only orthogonally reachable ones.
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 4),
            tank(1, .ai, .medium, 8, 4),
        ])
        let threat = ThreatMap(threatTo: .player, in: state)

        XCTAssertEqual(threat.damage(at: p(3, 4)), 4, "Reachable at 3 tiles, then a 2-tile shot")
        XCTAssertEqual(threat.damage(at: p(2, 4)), 0, "Out of reach this turn")
        XCTAssertEqual(threat.damage(at: p(0, 4)), 0)
    }

    func testTanksWithoutAmmoThreatenNothing() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 4),
            tank(1, .ai, .medium, 2, 4, ammo: 0),
        ])
        XCTAssertEqual(ThreatMap(threatTo: .player, in: state).damage(at: p(1, 4)), 0)
    }

    func testArtilleryCannotCoverItsOwnDoorstep() throws {
        // An artillery piece walled in by rocks cannot drive anywhere, so its
        // min range of 2 leaves a genuine dead zone around it. (On open ground
        // there is no such hole: it simply reverses a tile and shells the one
        // it was standing on, which is why this test has to pin it down.)
        let pinned = """
            S.....a
            .......
            .RRR...
            .R.R...
            .RRR...
            .......
            P.....s
            """
        let state = try makeState(pinned, tanks: [
            tank(0, .player, .light, 0, 6),
            tank(1, .ai, .artillery, 2, 3),
        ])
        let threat = ThreatMap(threatTo: .player, in: state)

        XCTAssertEqual(threat.damage(at: p(2, 3)), 0, "Its own tile")
        XCTAssertEqual(threat.damage(at: p(2, 2)), 0, "1 away, below min range")
        XCTAssertEqual(threat.damage(at: p(2, 1)), 5, "2 away")
        XCTAssertEqual(threat.damage(at: p(2, 0)), 5, "3 away")
        XCTAssertEqual(threat.damage(at: p(6, 3)), 5, "4 away, exactly max range")
        XCTAssertEqual(threat.damage(at: p(6, 4)), 0, "5 away, beyond max range")
    }

    func testFirepowerFromSeveralEnemiesStacks() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 8),
            tank(1, .ai, .medium, 4, 4),
            tank(2, .ai, .artillery, 6, 4),
        ])
        let threat = ThreatMap(threatTo: .player, in: state)
        XCTAssertEqual(threat.damage(at: p(4, 2)), 9, "Medium 4 + artillery 5")
    }

    func testLethalityIsRelativeToRemainingHP() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 4, hp: 3),
            tank(1, .ai, .medium, 8, 4),
        ])
        let threat = ThreatMap(threatTo: .player, in: state)
        let wounded = state.tanks[0]
        XCTAssertTrue(threat.isLethal(for: wounded, at: p(3, 4)), "3 HP vs 4 damage")
        XCTAssertFalse(threat.isLethal(for: wounded, at: p(0, 4)))
    }
}

// MARK: - Scoring

final class GreedyEvaluatorTests: XCTestCase {

    func testTakesTheKillOverMoreDamageElsewhere() throws {
        // Artillery can either finish the 2-HP light or chip the full medium.
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .artillery, 4, 4),
            tank(1, .ai, .light, 4, 1, hp: 2),
            tank(2, .ai, .medium, 7, 4),
        ])

        let action = GreedyAI().chooseAction(in: state)
        XCTAssertEqual(chosenCommand(action)?.targetID, 1,
                       "A kill is worth more than 5 damage spread around")
    }

    func testRefusesATradeThatLosesTheTank() throws {
        // A 2-HP light next to a full medium: 3 damage out, 4 back, and it dies.
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 4, 4, hp: 2),
            tank(1, .ai, .medium, 5, 4),
        ])

        let holdAndFire = TankCommand(tankID: 0, destination: p(4, 4), targetID: 1)
        XCTAssertLessThan(score(holdAndFire, in: state).total, AIWeights.standard.passScore,
                          "A losing shot must rank below doing nothing at all")
        XCTAssertNil(chosenCommand(GreedyAI().chooseAction(in: state))?.targetID,
                     "Not worth a tank")
    }

    func testTradesWhenItWinsTheMatch() throws {
        // Same bad trade, except the medium is the last AI tank and dies to it:
        // ending the match outranks keeping the tank.
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 4, 4, hp: 2),
            tank(1, .player, .light, 0, 8),
            tank(2, .ai, .medium, 5, 4, hp: 3),
        ])

        let command = chosenCommand(GreedyAI().chooseAction(in: state))
        XCTAssertEqual(command?.tankID, 0)
        XCTAssertEqual(command?.targetID, 2)
    }

    func testDrivesADryTankToItsSupplyTile() throws {
        // Out of ammo and nearly dead, one tile from the supply depot.
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 1, 0, hp: 1, ammo: 0),
            tank(1, .ai, .medium, 8, 8),
        ])

        let command = chosenCommand(GreedyAI().chooseAction(in: state))
        XCTAssertEqual(command?.destination, p(0, 0), "Refill HP and ammo")
        XCTAssertGreaterThan(score(TankCommand(tankID: 0, destination: p(0, 0)), in: state).supply, 0)
    }

    func testHealthyTanksGetNoSupplyBonus() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 1, 0),
            tank(1, .ai, .medium, 8, 8),
        ])
        XCTAssertEqual(score(TankCommand(tankID: 0, destination: p(0, 0)), in: state).supply, 0)
    }

    func testClosesInWhenNothingIsInRange() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 0, 4),
            tank(1, .ai, .medium, 8, 4),
        ])

        let command = chosenCommand(GreedyAI().chooseAction(in: state))
        XCTAssertNotNil(command, "Standing still achieves nothing")
        XCTAssertGreaterThan(command?.destination.x ?? 0, 0, "Should advance on the enemy")
        XCTAssertNil(command?.targetID, "Nothing to shoot yet")
    }

    func testPrefersTheQuieterOfTwoEqualTiles() throws {
        // Both destinations are 1 tile of progress towards the medium, but one
        // walks into the artillery's reach. Approach is switched off so only the
        // threat map is under test.
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .medium, 0, 4),
            tank(1, .ai, .medium, 8, 4),
            tank(2, .ai, .artillery, 4, 0),
        ])
        var weights = AIWeights.standard
        weights.approachBonus = 0

        let exposed = score(TankCommand(tankID: 0, destination: p(0, 2)), in: state, weights: weights)
        let quiet = score(TankCommand(tankID: 0, destination: p(0, 6)), in: state, weights: weights)
        XCTAssertLessThan(exposed.exposure, 0, "Walks into artillery range")
        XCTAssertEqual(quiet.exposure, 0)
        XCTAssertGreaterThan(quiet.total, exposed.total)
    }

    func testHoldsGroundRatherThanPassing() throws {
        // A tank walled in by rocks with no enemy in reach has exactly one
        // thing it can do, and "hold position" says it better than `.pass`.
        let pocket = """
            S.a..
            .RRR.
            .R.R.
            .RRR.
            P...s
            """
        let state = try makeState(pocket, tanks: [
            tank(0, .player, .light, 2, 2),
            tank(1, .ai, .light, 2, 0),
        ])

        let ranked = GreedyAI().rankedCandidates(in: state)
        let best = ranked.first?.candidate
        XCTAssertEqual(best?.destination, p(2, 2))
        XCTAssertNil(best?.target)
        XCTAssertGreaterThan(ranked.first?.score.total ?? 0,
                             ranked.last?.score.total ?? 0)
        XCTAssertEqual(ranked.last?.candidate.action, .pass,
                       "Pass is the floor: holding position dominates it")
    }

    func testACautiousTankRunsFromLethalFire() throws {
        // 1 HP, two mediums converging. The standard tuning keeps it where it
        // is (and would rather act with another tank); the cautious one, which
        // values getting out alive, pulls it back out of reach.
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 4, 4, hp: 1),
            tank(1, .ai, .medium, 4, 2),
            tank(2, .ai, .medium, 4, 6),
        ])
        let threat = ThreatMap(threatTo: .player, in: state)
        XCTAssertTrue(threat.isLethal(for: state.tanks[0], at: p(4, 4)))

        let command = chosenCommand(GreedyAI(weights: .cautious).chooseAction(in: state))
        let destination = try XCTUnwrap(command?.destination)
        XCTAssertNotEqual(destination, p(4, 4), "Staying put is death")
        XCTAssertLessThan(threat.damage(at: destination), threat.damage(at: p(4, 4)),
                          "Moved somewhere quieter")
    }

    func testAHealthyTankAdvancesIntoContact() throws {
        // The medium is at full HP and the enemy's envelope reaches x >= 3, so
        // closing in means accepting fire. It has to be willing: an exposure
        // term strong enough to veto this is what froze the first version of
        // this evaluator into a 40-round staring contest.
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .medium, 0, 4),
            tank(1, .ai, .medium, 8, 4),
        ])
        let threat = ThreatMap(threatTo: .player, in: state)

        let destination = try XCTUnwrap(chosenCommand(GreedyAI().chooseAction(in: state))?.destination)
        XCTAssertEqual(destination, p(3, 4), "All 3 move points spent closing")
        XCTAssertGreaterThan(threat.strongestShot(at: destination), 0,
                             "Advancing into the enemy's reach is the point")
    }

    func testADryTankHeadsForTheDepotFromAcrossTheMap() throws {
        // Out of ammo and 6 tiles from the depot: arriving is two turns away,
        // so the only thing that can start the trip is credit for the ground
        // covered. Without it the tank sits where it is for the whole match.
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 6, 0, hp: 1, ammo: 0),
            tank(1, .ai, .medium, 8, 8),
        ])
        let depot = try XCTUnwrap(state.map.supplyTiles[.player])

        let destination = try XCTUnwrap(chosenCommand(GreedyAI().chooseAction(in: state))?.destination)
        XCTAssertLessThan(destination.manhattanDistance(to: depot),
                          p(6, 0).manhattanDistance(to: depot),
                          "Should set off for the depot, not wait next to it")
    }

    func testDrivesRoundAnObstacleInsteadOfStaringAcrossIt() throws {
        // The regression test for approach-by-Manhattan: every tile that makes
        // real progress round the dam looks like a step BACKWARDS in a straight
        // line, so the AI used to park its army on the bank for the rest of the
        // match rather than take one.
        let state = try makeState(dammedMap, tanks: [
            tank(0, .player, .medium, 2, 2),
            tank(1, .ai, .medium, 2, 0),
        ], currentSide: .ai)
        let field = DistanceField(to: [p(2, 2)], movingAs: .ai, in: state)

        let destination = try XCTUnwrap(chosenCommand(GreedyAI().chooseAction(in: state))?.destination)
        XCTAssertGreaterThan(field.progress(from: p(2, 0), to: destination), 0,
                             "Has to be closer to DRIVE, not closer in a straight line")
        XCTAssertGreaterThanOrEqual(destination.manhattanDistance(to: p(2, 2)),
                                    p(2, 0).manhattanDistance(to: p(2, 2)),
                                    "And a straight line would have called this no better")
    }

    func testAnEvenTradeIsWorthMaking() throws {
        // Medium against medium: 4 out, 4 back, and the attacker is left on 6
        // HP, which no single enemy gun can finish. Scored at parity this is a
        // wash and the AI holds instead; priced with a point dealt worth
        // slightly more than a point taken it engages — and that is what lets
        // it finish a passive opponent inside the round limit (see
        // `testFinishesOffAPlayerThatNeverMoves`). The brake on this is
        // `lethalExposurePenalty`, which still refuses a trade that leaves the
        // attacker inside one shot of death: see `testRefusesATradeThatLosesTheTank`.
        let state = try makeState(openMap, tanks: [
            tank(0, .ai, .medium, 4, 4),
            tank(1, .player, .medium, 4, 5),
            tank(2, .player, .light, 0, 0),
        ], currentSide: .ai)

        let trade = score(TankCommand(tankID: 0, destination: p(4, 4), targetID: 1), in: state)
        XCTAssertEqual(trade.damage, 4)
        XCTAssertGreaterThan(trade.damage + trade.counter, 0,
                             "A point dealt has to outweigh a point taken")
        XCTAssertEqual(chosenCommand(GreedyAI().chooseAction(in: state))?.targetID, 1)
    }

    func testScoreBreakdownAddsUp() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .medium, 4, 4),
            tank(1, .ai, .light, 5, 4, hp: 2),
        ])
        let s = score(TankCommand(tankID: 0, destination: p(4, 4), targetID: 1), in: state)
        XCTAssertEqual(s.damage, 2, "Damage is capped at the target's HP")
        XCTAssertEqual(s.kill, AIWeights.standard.killBonus)
        XCTAssertEqual(s.counter, 0, "A destroyed tank does not fire back")
        XCTAssertEqual(s.total, s.damage + s.kill + s.outcome + s.exposure + s.approach, accuracy: 0.0001)
    }
}

// MARK: - The brain as a whole

final class GreedyAITests: XCTestCase {

    func testIsDeterministicWithoutJitter() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 2, 4),
            tank(1, .player, .artillery, 1, 6),
            tank(2, .ai, .medium, 6, 4),
            tank(3, .ai, .light, 7, 2),
        ])
        let ai = GreedyAI()
        let first = ai.chooseAction(in: state)
        for _ in 0..<5 {
            XCTAssertEqual(ai.chooseAction(in: state), first)
        }
    }

    func testJitterIsReproducibleForAGivenSeed() throws {
        let state = try makeState(openMap, tanks: [
            tank(0, .player, .light, 2, 4),
            tank(1, .ai, .medium, 6, 4),
        ])
        var weights = AIWeights.standard
        weights.jitter = 2.0

        let a = GreedyAI(weights: weights, seed: 99)
        XCTAssertEqual(a.chooseAction(in: state), a.chooseAction(in: state),
                       "The same seed and position must replay")
        let scores = { (ai: GreedyAI) in ai.rankedCandidates(in: state).map(\.score.total) }
        XCTAssertNotEqual(scores(a), scores(GreedyAI(weights: weights, seed: 1234)),
                          "A different seed must explore differently")
    }

    func testAlwaysReturnsALegalAction() throws {
        // Including the awkward cases: no ammo anywhere, and nowhere to drive.
        let boxed = """
            S..a
            .RR.
            .RR.
            P..s
            """
        let state = try makeState(boxed, tanks: [
            tank(0, .player, .light, 0, 3, ammo: 0),
            tank(1, .ai, .light, 3, 0, ammo: 0),
        ])
        XCTAssertNoThrow(try Rules.apply(GreedyAI().chooseAction(in: state), to: state))
    }

    func testPassesOnceTheMatchIsOver() throws {
        let state = try makeState(openMap, tanks: [tank(0, .player, .light, 1, 1)],
                                  status: .finished(.win(.player, .annihilation)))
        XCTAssertEqual(GreedyAI().chooseAction(in: state), .pass)
    }
}

// MARK: - Whole matches

final class AIMatchTests: XCTestCase {

    private func newGame() throws -> GameState {
        try GameState.newGame(config: .phase1Default, map: try GameMap(ascii: Maps.crossing))
    }

    func testAMatchFinishesWithinTheRoundLimit() throws {
        let outcome = AIMatch.play(try newGame(), player: GreedyAI(), ai: GreedyAI())

        XCTAssertTrue(outcome.state.isOver)
        XCTAssertNotNil(outcome.result)
        XCTAssertTrue(outcome.illegalActions.isEmpty,
                      "The generator offered something the rules rejected")
        XCTAssertLessThanOrEqual(outcome.state.round, outcome.state.config.maxRounds)
    }

    func testTwoBrainsFightInsteadOfStaringAtEachOther() throws {
        // The regression test for the first tuning of this evaluator: both
        // sides advanced to the edge of each other's threat map, found every
        // step into contact priced above the ground it won, and held position
        // for 40 rounds. Legal, terminating, and a completely dead match — so
        // legality is not enough to assert here. Shots have to be fired.
        let start = try newGame()
        let outcome = AIMatch.play(start, player: GreedyAI(), ai: GreedyAI())

        let hpBefore = Side.allCases.reduce(0) { $0 + start.totalHP(of: $1) }
        let hpAfter = Side.allCases.reduce(0) { $0 + outcome.state.totalHP(of: $1) }
        XCTAssertGreaterThan(hpBefore - hpAfter, 15,
                             "Barely any damage dealt in a whole match")
        XCTAssertGreaterThanOrEqual(outcome.state.tanks.filter { !$0.isAlive }.count, 1,
                                    "Nobody even lost a tank")
        XCTAssertFalse(outcome.actions.contains(.pass),
                       "Holding position says it better than passing")
    }

    func testFinishesOffAPlayerThatNeverMoves() throws {
        // The sharpest end-to-end check there is: against five stationary
        // tanks, an opponent worth playing should cross the map and wipe them
        // out inside the round limit. Both of the bugs this file guards against
        // — the army stuck behind the river, the refusal to trade — showed up
        // here as a win on HP instead of by annihilation.
        let outcome = AIMatch.play(try newGame(), player: PassiveAI(), ai: GreedyAI())

        XCTAssertEqual(outcome.result, .win(.ai, .annihilation),
                       "Round \(outcome.state.round), blue on "
                        + "\(outcome.state.totalHP(of: .player)) HP")
    }

    func testGreedyBeatsRandomFromEitherSide() throws {
        let asPlayer = AIMatch.play(try newGame(), player: GreedyAI(), ai: RandomAI())
        XCTAssertEqual(asPlayer.result.flatMap(winner), .player, "Greedy as player: \(asPlayer.result!)")

        let asAI = AIMatch.play(try newGame(), player: RandomAI(), ai: GreedyAI())
        XCTAssertEqual(asAI.result.flatMap(winner), .ai, "Greedy as AI: \(asAI.result!)")

        for outcome in [asPlayer, asAI] {
            XCTAssertTrue(outcome.illegalActions.isEmpty)
        }
    }

    func testRecklessAndCautiousTuningsBothPlayLegally() throws {
        let outcome = AIMatch.play(try newGame(),
                                   player: GreedyAI(weights: .reckless, name: "Reckless"),
                                   ai: GreedyAI(weights: .cautious, name: "Cautious"))
        XCTAssertTrue(outcome.state.isOver)
        XCTAssertTrue(outcome.illegalActions.isEmpty)
    }

    func testTallyCountsEveryMatch() throws {
        let record = AIMatch.tally(try newGame(), player: GreedyAI(), ai: RandomAI(), count: 3)
        XCTAssertEqual(record.total, 3)
    }

    func testWeightsSurviveAJSONRoundTrip() throws {
        let data = try JSONEncoder().encode(AIWeights.cautious)
        XCTAssertEqual(try AIWeights.load(fromJSON: data), .cautious)
    }

    // MARK: Twin Lakes

    /// The 12 x 18 map is a long march — over 25 tiles corner to corner — and
    /// the AI has to make it from either corner and still finish the job.
    func testFinishesOffAPlayerThatNeverMovesOnTheTwinLakes() throws {
        let start = try GameState.newGame(map: try Maps.twinLakes().map)
        let asAI = AIMatch.play(start, player: PassiveAI(), ai: GreedyAI())
        XCTAssertEqual(asAI.result, .win(.ai, .annihilation), "Round \(asAI.state.round)")

        let asPlayer = AIMatch.play(start, player: GreedyAI(), ai: PassiveAI())
        XCTAssertEqual(asPlayer.result, .win(.player, .annihilation), "Round \(asPlayer.state.round)")
    }

    func testGreedyBeatsRandomOnTheTwinLakes() throws {
        let start = try GameState.newGame(map: try Maps.twinLakes().map)
        let asAI = AIMatch.play(start, player: RandomAI(), ai: GreedyAI())
        XCTAssertEqual(asAI.result.flatMap(winner), .ai, "Greedy as AI: \(asAI.result!)")
        XCTAssertTrue(asAI.illegalActions.isEmpty)
    }

    private func winner(_ result: GameResult) -> Side? {
        if case .win(let side, _) = result { return side }
        return nil
    }
}
