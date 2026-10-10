import XCTest
@testable import TankGameRendering
import TankGameAI
import TankGameCore

/// The same 7x5 open board the tap-flow tests use.
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

/// A board where Red is played by an AI, unlike the hot-seat default.
private func makeInteraction(_ tanks: [Tank],
                             currentSide: Side = .player,
                             aiSide: Side? = .ai) throws -> BoardInteraction {
    let state = GameState(config: .phase1Default, map: try GameMap(ascii: testMap),
                          tanks: tanks, currentSide: currentSide, round: 1, status: .ongoing)
    return BoardInteraction(state: state, aiSide: aiSide)
}

/// Answers with whatever it was given, legal or not.
private struct StubAI: TankAI {
    let name = "Stub"
    let answer: Action
    func chooseAction(in state: GameState) -> Action { answer }
}

final class AIOpponentTests: XCTestCase {

    // MARK: Whose turn it is

    func testSwallowsEveryInputDuringRedsTurn() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 0, 4),
            tank(1, .ai, .medium, 6, 0),
        ], currentSide: .ai)

        XCTAssertTrue(interaction.isAITurn)
        XCTAssertFalse(interaction.acceptsInput)
        XCTAssertFalse(interaction.canPass)

        // Red's own tank must not become selectable just because it is Red's
        // turn: that is exactly the hot-seat behaviour this has to suppress.
        interaction.tapTile(p(6, 0))
        XCTAssertNil(interaction.selectedTankID)
        XCTAssertFalse(interaction.canWait)

        let before = interaction.state
        interaction.pass()
        interaction.wait()
        interaction.attack()
        XCTAssertEqual(interaction.state, before, "Nothing the player taps may spend Red's turn")
    }

    func testBlueKeepsTheBoardOnItsOwnTurn() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 0, 4),
            tank(1, .ai, .medium, 6, 0),
        ])
        XCTAssertFalse(interaction.isAITurn)
        XCTAssertTrue(interaction.acceptsInput)

        interaction.tapTile(p(0, 4))
        XCTAssertEqual(interaction.selectedTankID, 0)

        // And asking for Red's move on Blue's turn does nothing at all.
        let before = interaction.state
        XCTAssertTrue(interaction.takeAIAction(with: GreedyAI()).isEmpty)
        XCTAssertEqual(interaction.state, before)
    }

    func testHotSeatStillLetsBothSidesPlay() throws {
        // Milestone 2's behaviour has to survive: with no AI side, Red's tanks
        // are selectable on Red's turn.
        var interaction = try makeInteraction([
            tank(0, .player, .light, 0, 4),
            tank(1, .ai, .medium, 6, 0),
        ], currentSide: .ai, aiSide: nil)

        XCTAssertFalse(interaction.isAITurn)
        interaction.tapTile(p(6, 0))
        XCTAssertEqual(interaction.selectedTankID, 1)
        XCTAssertTrue(interaction.canPass)
    }

    // MARK: Taking the turn

    func testPlaysEveryOneOfItsTanksBeforeHandingTheBoardBack() throws {
        // A turn is one action per tank, so one call to `takeAIAction` is one
        // tank: the scene keeps calling while `isAITurn` holds.
        var interaction = try makeInteraction([
            tank(0, .player, .light, 0, 4),
            tank(1, .ai, .light, 6, 0),
            tank(2, .ai, .medium, 5, 0),
            tank(3, .ai, .artillery, 4, 0),
        ], currentSide: .ai)

        var actions = 0
        while interaction.isAITurn, actions < 10 {
            interaction.takeAIAction(with: GreedyAI())
            actions += 1
        }

        XCTAssertEqual(actions, 3, "One action per Red tank")
        XCTAssertEqual(interaction.currentSide, .player)
    }

    func testPlaysRedsTurnAndHandsTheBoardBack() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 0, 4),
            tank(1, .ai, .medium, 6, 0),
        ], currentSide: .ai)

        let events = interaction.takeAIAction(with: GreedyAI())

        XCTAssertFalse(events.isEmpty, "The turn has to produce something to animate")
        XCTAssertEqual(interaction.currentSide, .player, "Red's only tank acted")
        XCTAssertFalse(interaction.isAITurn)
        XCTAssertTrue(interaction.acceptsInput)
        XCTAssertEqual(interaction.phase, .idle)
    }

    func testRedsTurnClearsWhateverBlueWasLookingAt() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 0, 4),
            tank(1, .ai, .medium, 6, 0),
        ])
        // Blue inspects a tank, then ends its turn; Red moves next.
        interaction.tapTile(p(6, 0))
        interaction.pass()
        interaction.takeAIAction(with: GreedyAI())

        XCTAssertNil(interaction.inspectedTankID)
        XCTAssertNil(interaction.describedTankID)
        XCTAssertTrue(interaction.moveHighlights.isEmpty)
    }

    func testABrainOfferingAnIllegalActionLosesItsTurnInsteadOfWedgingTheMatch() throws {
        var interaction = try makeInteraction([
            tank(0, .player, .light, 0, 4),
            tank(1, .ai, .medium, 6, 0),
        ], currentSide: .ai)
        // Commanding Blue's tank on Red's turn: the rules reject it.
        let cheat = StubAI(answer: .command(TankCommand(tankID: 0, destination: p(0, 3))))

        let events = interaction.takeAIAction(with: cheat)

        XCTAssertEqual(events, [.passed(.ai), .turnBegan(.player, round: 2)])
        XCTAssertEqual(interaction.currentSide, .player, "The match has to move on")
        XCTAssertEqual(interaction.state.tanks, [tank(0, .player, .light, 0, 4),
                                                 tank(1, .ai, .medium, 6, 0)],
                       "...without the illegal action having happened")
    }

    // MARK: End to end

    func testRedPlaysAMatchOutAgainstAPassivePlayer() throws {
        // Blue passes every turn. A wired-up opponent should walk over it —
        // and the loop should never stall, which is the thing the scene's
        // hand-over has to get right.
        let state = try GameState.newGame(config: .phase1Default,
                                          map: try GameMap(ascii: Maps.crossing))
        var interaction = BoardInteraction(state: state, aiSide: .ai)
        let opponent = GreedyAI()
        var actions = 0

        // A turn is now up to five actions a side, so the cap counts actions,
        // not rounds: 40 rounds of five Red tanks and one Blue pass is ~240.
        while !interaction.isOver, actions < 600 {
            if interaction.isAITurn {
                // Not "produces events": a tank holding its position produces
                // none. What has to be true is that the turn moved on.
                let before = interaction.state
                interaction.takeAIAction(with: opponent)
                XCTAssertNotEqual(interaction.state, before,
                                  "An action that changes nothing would loop forever")
            } else {
                XCTAssertTrue(interaction.canPass)
                interaction.pass()
            }
            actions += 1
        }

        XCTAssertTrue(interaction.isOver, "Stalled after \(actions) actions")
        XCTAssertEqual(interaction.state.status, .finished(.win(.ai, .annihilation)))
        XCTAssertFalse(interaction.acceptsInput, "Nothing to tap once the match is over")
    }
}
