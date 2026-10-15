import XCTest
import SpriteKit
@testable import TankGameRendering
import TankGameCore

/// Each type of tank drives at its own speed on screen: the light fastest, the
/// artillery slowest. Read off the drive the board actually starts, so this
/// checks the animation rather than restating the numbers.
@MainActor
final class DriveSpeedTests: XCTestCase {

    private let map = """
        S.....a
        .......
        .......
        .......
        P.....s
        """

    private func tank(_ id: TankID, _ kind: TankKind, row: Int) -> Tank {
        let stats = GameConfig.phase1Default.stats(for: kind)
        return Tank(id: id, side: .player, kind: kind, position: Position(x: 1, y: row),
                    hp: stats.maxHP, ammo: stats.maxAmmo)
    }

    /// Starts a 2-tile drive for one tank and reports how long it will take.
    private func driveTime(of kind: TankKind) throws -> TimeInterval? {
        let tanks = [tank(0, .light, row: 0), tank(1, .medium, row: 1), tank(2, .artillery, row: 2)]
        let state = GameState(config: .phase1Default, map: try GameMap(ascii: map), tanks: tanks,
                              currentSide: .player, round: 1, status: .ongoing)
        let board = BoardNode(state: state,
                              catalog: SpriteCatalog(bundle: Bundle(for: DriveSpeedTests.self)))
        let mover = try XCTUnwrap(tanks.first { $0.kind == kind })
        let row = mover.position.y
        let path = [Position(x: 1, y: row), Position(x: 2, y: row), Position(x: 3, y: row)]

        board.play([.moved(mover.id, path: path)], state: state) {}
        return board.runningDriveDuration(tankID: mover.id)
    }

    func testEachTypeDrivesAtItsOwnSpeed() throws {
        let speed = DriveSpeed()
        XCTAssertEqual(try driveTime(of: .light) ?? 0, 2 * speed.light, accuracy: 0.001)
        XCTAssertEqual(try driveTime(of: .medium) ?? 0, 2 * speed.medium, accuracy: 0.001)
        XCTAssertEqual(try driveTime(of: .artillery) ?? 0, 2 * speed.artillery, accuracy: 0.001)
    }

    func testTheLightIsFastestAndTheArtillerySlowest() {
        let speed = DriveSpeed()
        XCTAssertEqual(speed.light, 0.10, "The light keeps the speed every tank used to have")
        XCTAssertLessThan(speed.light, speed.medium)
        XCTAssertLessThan(speed.medium, speed.artillery)
    }

    func testAFullMoveTakesAboutTheSameTimeForEveryType() {
        // Slower tanks also move fewer tiles, so no type's longest drive drags.
        let speed = DriveSpeed()
        let config = GameConfig.phase1Default
        for kind in TankKind.allCases {
            let fullMove = Double(config.stats(for: kind).movePoints) * speed.secondsPerTile(for: kind)
            XCTAssertEqual(fullMove, 0.5, accuracy: 0.03, "\(kind)")
        }
    }
}
