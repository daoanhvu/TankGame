import XCTest
@testable import TankGameRendering
@testable import TankGameCore

/// Tiles along a row, for readable routes: `row(0, 1, 2)` is (0,0) → (1,0) → (2,0).
private func row(_ xs: Int...) -> [Position] {
    xs.map { Position(x: $0, y: 0) }
}

final class PreviewRouteTests: XCTestCase {

    func testDrivingOutFromTheHomeTile() {
        // Standing at home, told to go three tiles east: drive all three.
        XCTAssertEqual(PreviewRoute.tiles(from: row(0), to: row(0, 1, 2, 3)),
                       row(1, 2, 3))
    }

    func testStayingPutDrivesNothing() {
        XCTAssertEqual(PreviewRoute.tiles(from: row(0), to: row(0)), [])
    }

    func testExtendingTheSameRouteCarriesOnForward() {
        // Already at (2,0) via (1,0); now asked to go one further. It should
        // just roll on, not reverse home and start again.
        XCTAssertEqual(PreviewRoute.tiles(from: row(0, 1, 2), to: row(0, 1, 2, 3)),
                       row(3))
    }

    func testShorteningTheSameRouteReversesBack() {
        XCTAssertEqual(PreviewRoute.tiles(from: row(0, 1, 2, 3), to: row(0, 1)),
                       row(2, 1))
    }

    func testCancellingAMoveDrivesAllTheWayHome() {
        XCTAssertEqual(PreviewRoute.tiles(from: row(0, 1, 2), to: row(0)),
                       row(1, 0))
    }

    func testDivergingRouteReversesToTheForkThenDrivesOut() {
        // Shares (0,0) → (1,0), then the new route turns off southwards.
        let current = [Position(x: 0, y: 0), Position(x: 1, y: 0), Position(x: 2, y: 0)]
        let target = [Position(x: 0, y: 0), Position(x: 1, y: 0), Position(x: 1, y: 1)]
        XCTAssertEqual(PreviewRoute.tiles(from: current, to: target),
                       [Position(x: 1, y: 0), Position(x: 1, y: 1)],
                       "Back to the fork at (1,0), then out to (1,1)")
    }

    func testCompletelyDifferentRouteGoesHomeFirst() {
        // Only the home tile is shared, so it has to reverse the whole way.
        let current = [Position(x: 0, y: 0), Position(x: 1, y: 0)]
        let target = [Position(x: 0, y: 0), Position(x: 0, y: 1)]
        XCTAssertEqual(PreviewRoute.tiles(from: current, to: target),
                       [Position(x: 0, y: 0), Position(x: 0, y: 1)])
    }

    func testEveryStepIsASingleOrthogonalTile() {
        // The stitched route must still be drivable one tile at a time, or the
        // animation would slide the tank diagonally across the board.
        let current = row(0, 1, 2, 3)
        let target = [Position(x: 0, y: 0), Position(x: 1, y: 0), Position(x: 1, y: 1)]
        let route = PreviewRoute.tiles(from: current, to: target)

        var previous = current[current.count - 1]
        for tile in route {
            XCTAssertEqual(previous.manhattanDistance(to: tile), 1,
                           "\(previous) → \(tile) is not a single step")
            previous = tile
        }
    }

    func testEmptyInputsAreHandled() {
        XCTAssertEqual(PreviewRoute.tiles(from: [], to: row(0, 1)), row(0, 1))
        XCTAssertEqual(PreviewRoute.tiles(from: row(0, 1), to: []), [])
    }
}
