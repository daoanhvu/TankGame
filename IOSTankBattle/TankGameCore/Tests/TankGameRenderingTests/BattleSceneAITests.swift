#if canImport(AppKit)
import XCTest
import AppKit
import SpriteKit
@testable import TankGameRendering
import TankGameCore
import TankGameAI

/// The scene's own hand-over to the opponent, driven by a real SpriteKit
/// render loop rather than by calling the pieces directly.
///
/// `BoardInteraction` is where the turn rules live and where they are tested;
/// what is left in `BattleScene` is the scheduling — wait a beat, ask the
/// brain, animate, hand the board back — and the way that breaks is by simply
/// never happening, which no amount of testing the parts would catch.
///
/// macOS only: it needs a window for SpriteKit to run its clock.
@MainActor
final class BattleSceneAITests: XCTestCase {

    /// A scene in a real (off-screen) window, with the think delay cut short.
    private func makeScene(opponent: TankAI? = GreedyAI()) throws -> BattleScene {
        let size = CGSize(width: 500, height: 900)
        let scene = try BattleScene(size: size, opponent: opponent)
        scene.opponentDelay = 0.05

        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let window = NSWindow(contentRect: view.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = view
        window.orderBack(nil)
        windows.append(window)          // keep it alive for the test's duration
        view.presentScene(scene)
        return scene
    }

    private var windows: [NSWindow] = []

    override func tearDown() {
        windows.removeAll()
        super.tearDown()
    }

    /// Spins the run loop until `condition` holds, so the scene's actions and
    /// animations actually run. Returns false if it never does.
    private func wait(upTo seconds: TimeInterval = 5,
                      for condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        return condition()
    }

    func testRedPlaysItsTurnAndHandsTheBoardBack() throws {
        let scene = try makeScene()
        XCTAssertEqual(scene.currentState.currentSide, .player)
        XCTAssertFalse(scene.isOpponentTurn)

        scene.simulatePass()
        XCTAssertTrue(scene.isOpponentTurn, "Red owes the game a move now")

        XCTAssertTrue(wait { scene.isAcceptingInput }, "Red never moved")
        XCTAssertFalse(scene.isOpponentTurn)
        XCTAssertEqual(scene.currentState.currentSide, .player)
        XCTAssertEqual(scene.currentState.round, 2, "A full round went by")
    }

    func testKeepsHandingOverRoundAfterRound() throws {
        // The scheduling bug this guards against is the one-shot kind: Red
        // moves once, then the board never asks it again because the hand-over
        // sits in the wrong place.
        let scene = try makeScene()

        for round in 1...3 {
            XCTAssertEqual(scene.currentState.round, round)
            scene.simulatePass()
            // Waiting on `isAcceptingInput`, not merely on the turn flipping:
            // Red's move is still animating for a moment after its action has
            // been applied, and the board rightly swallows taps until it lands.
            XCTAssertTrue(wait { scene.isAcceptingInput },
                          "The board never came back after round \(round)")
        }
        XCTAssertEqual(scene.currentState.round, 4)
    }

    func testRedCommandsEveryTankBeforeHandingBack() throws {
        // A turn is one action per tank, so Red's turn is five animations, not
        // one. Watching how many of its tanks have acted at the peak is what
        // tells a full turn apart from a single move that happened to end it.
        let scene = try makeScene()
        var mostActed = 0

        scene.simulatePass()
        _ = wait { 
            mostActed = max(mostActed, scene.currentState.actedThisTurn.count)
            return scene.isAcceptingInput
        }

        XCTAssertEqual(scene.currentState.currentSide, .player)
        XCTAssertGreaterThan(mostActed, 1, "Red played a single tank and stopped")
    }

    func testAnActionWithNothingToAnimateStillHandsOver() throws {
        // Holding position (tapping a tank twice) produces no events
        // whatsoever: there is no `.moved` to draw, and `.turnBegan` only fires
        // when the side changes.
        // A scene that reads "no events" as "the rules declined that" leaves
        // the board on Red's turn with input locked and no way out.
        let scene = try makeScene()
        let blueTanks = scene.currentState.aliveTanks(of: .player)

        for tank in blueTanks {
            XCTAssertTrue(scene.isAcceptingInput, "Blue's turn stalled at tank \(tank.id)")
            scene.simulateTap(onTile: tank.position)   // select: Tile1 is its own tile
            scene.simulateTap(onTile: tank.position)   // again: hold position
            _ = wait(upTo: 1) { scene.isAcceptingInput }
        }

        // Both conditions: the round counter turns over when Red's last action
        // is applied, while its move is still being drawn.
        XCTAssertTrue(wait { scene.currentState.round == 2 && scene.isAcceptingInput },
                      "Red never got the board after a turn of tanks holding position")
        XCTAssertEqual(scene.currentState.currentSide, .player)
    }

    func testRedStillPlaysAfterBluesFirstMoveAndEndTurn() throws {
        // The bug report: make one move, press End Turn, and Red never moved —
        // the board stayed locked for good. An End Turn could start a drive
        // (sending a tank parked on a planned tile home) that refused Red's
        // turn and then never asked for it again. Covers both ways the first
        // move can be left: committed, and only pointed at.
        for commitTheMove in [true, false] {
            let scene = try makeScene()
            let state = scene.currentState
            let tank = try XCTUnwrap(state.aliveTanks(of: .player).first)
            let tile1 = try XCTUnwrap(Rules.reachableTiles(for: tank, in: state).keys
                .filter { $0 != tank.position }.min { ($0.y, $0.x) < ($1.y, $1.x) })

            scene.simulateTap(onTile: tank.position)
            scene.simulateTap(onTile: tile1)
            if commitTheMove { scene.simulateTap(onTile: tile1) }
            XCTAssertTrue(wait { scene.isAcceptingInput })

            scene.simulatePass()
            XCTAssertTrue(wait { scene.currentState.round == 2 && scene.isAcceptingInput },
                          "Red stuck after End Turn (move committed: \(commitTheMove))")
            XCTAssertEqual(scene.currentState.currentSide, .player)
        }
    }

    func testHotSeatLeavesRedToThePlayer() throws {
        let scene = try makeScene(opponent: nil)
        scene.simulatePass()

        XCTAssertEqual(scene.currentState.currentSide, .ai)
        XCTAssertFalse(scene.isOpponentTurn, "Nobody is playing Red but the player")
        // Give it the time an opponent would have taken, and confirm the board
        // is still sitting on Red's turn waiting for a tap.
        _ = wait(upTo: 0.5) { false }
        XCTAssertTrue(scene.isAcceptingInput, "Red's turn is the player's to tap out")
        XCTAssertEqual(scene.currentState.currentSide, .ai)
        XCTAssertEqual(scene.currentState.round, 1)
    }

    func testSwappingTheBrainMidMatchKeepsThePositionAndCarriesOn() throws {
        // The difficulty-setting path: a new brain, the same match.
        let scene = try makeScene(opponent: nil)
        scene.simulatePass()
        XCTAssertEqual(scene.currentState.currentSide, .ai)

        scene.opponent = GreedyAI(weights: .cautious, name: "Cautious")
        XCTAssertTrue(wait { scene.isAcceptingInput }, "The new brain never took over")
        XCTAssertEqual(scene.currentState.round, 2)
    }
}
#endif
