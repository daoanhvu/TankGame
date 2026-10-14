#if canImport(AppKit)
import XCTest
import AppKit
import SpriteKit
@testable import TankGameRendering
import TankGameCore

/// What the player actually sees when moving a tank: choosing Tile1 leaves the
/// tank where it is, only tapping Tile1 again drives it, and the yellow X lands
/// on the enemies in range of Tile1.
///
/// macOS only: it needs a window for SpriteKit to run its clock.
@MainActor
final class BattleSceneMoveTests: XCTestCase {

    private var windows: [NSWindow] = []

    override func tearDown() {
        windows.removeAll()
        super.tearDown()
    }

    private func makeScene(newGame: (() throws -> GameState)? = nil) throws -> BattleScene {
        let size = CGSize(width: 500, height: 900)
        let scene = try newGame.map { try BattleScene(size: size, newGame: $0) }
            ?? BattleScene(size: size)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let window = NSWindow(contentRect: view.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = view
        window.orderBack(nil)
        windows.append(window)
        view.presentScene(scene)
        return scene
    }

    private func wait(upTo seconds: TimeInterval = 5, for condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        return condition()
    }

    /// A Blue tank and a tile it can reach that is not its own.
    private func blueTankAndDestination(in scene: BattleScene) throws -> (Tank, Position) {
        let state = scene.currentState
        let tank = try XCTUnwrap(state.aliveTanks(of: .player).first)
        let destination = try XCTUnwrap(Rules.reachableTiles(for: tank, in: state).keys
            .filter { $0 != tank.position }
            .min { ($0.y, $0.x) < ($1.y, $1.x) })
        return (tank, destination)
    }

    func testTheTankStaysPutUntilTile1IsTappedAgain() throws {
        let scene = try makeScene()
        let (tank, destination) = try blueTankAndDestination(in: scene)

        scene.simulateTap(onTile: tank.position)      // select
        scene.simulateTap(onTile: destination)        // Tile1
        // Give a drive every chance to start before checking it didn't.
        _ = wait(upTo: 0.6) { false }
        XCTAssertEqual(scene.tileShowing(tankID: tank.id), tank.position,
                       "Choosing Tile1 must not move the tank")
        XCTAssertTrue(scene.isAcceptingInput)

        scene.simulateTap(onTile: destination)        // Tile1 again: move
        XCTAssertTrue(wait { scene.isAcceptingInput && scene.tileShowing(tankID: tank.id) == destination },
                      "The second tap drives the tank there")
        XCTAssertEqual(scene.currentState.tanks[tank.id].position, destination,
                       "...and that is the committed move, not a preview")
        XCTAssertTrue(scene.currentState.hasActed(tank.id))
    }

    func testCancelLeavesTheTankWhereItWas() throws {
        let scene = try makeScene()
        let (tank, destination) = try blueTankAndDestination(in: scene)

        scene.simulateTap(onTile: tank.position)
        scene.simulateTap(onTile: destination)
        scene.simulateCancel()
        _ = wait(upTo: 0.3) { false }

        XCTAssertEqual(scene.tileShowing(tankID: tank.id), tank.position)
        XCTAssertEqual(scene.currentState.tanks[tank.id].position, tank.position)
        XCTAssertFalse(scene.currentState.hasActed(tank.id), "Cancel spends nothing")
        XCTAssertTrue(scene.targetMarkTiles().isEmpty, "...and clears the X's")
    }

    func testEnemiesInRangeOfTile1CarryTheYellowX() throws {
        // A small open board where the medium can reach a tile next to the
        // enemy: the X appears once that tile is Tile1, not before.
        let map = """
            S.....a
            .......
            .......
            .......
            P.....s
            """
        let stats = GameConfig.phase1Default.stats(for: .medium)
        let state = GameState(config: .phase1Default, map: try GameMap(ascii: map), tanks: [
            Tank(id: 0, side: .player, kind: .medium, position: Position(x: 0, y: 2),
                 hp: stats.maxHP, ammo: stats.maxAmmo),
            Tank(id: 1, side: .ai, kind: .medium, position: Position(x: 5, y: 2),
                 hp: stats.maxHP, ammo: stats.maxAmmo),
        ], currentSide: .player, round: 1, status: .ongoing)
        let scene = try makeScene { state }

        scene.simulateTap(onTile: Position(x: 0, y: 2))
        XCTAssertTrue(scene.targetMarkTiles().isEmpty, "5 away: nothing to mark")

        scene.simulateTap(onTile: Position(x: 3, y: 2))   // 2 from the enemy
        XCTAssertEqual(scene.targetMarkTiles(), [Position(x: 5, y: 2)])
    }
}
#endif
