import XCTest
import CoreGraphics
@testable import TankGameRendering
@testable import TankGameCore

final class BoardLayoutTests: XCTestCase {

    private let layout = BoardLayout(width: 12, height: 10, tileSize: 64)

    func testBoardSize() {
        XCTAssertEqual(layout.size, CGSize(width: 768, height: 640))
    }

    func testTileCentersFlipTheYAxis() {
        // Row 0 is the TOP row in the model, so it gets the HIGHEST y in SpriteKit.
        XCTAssertEqual(layout.point(for: Position(x: 0, y: 0)), CGPoint(x: 32, y: 608))
        XCTAssertEqual(layout.point(for: Position(x: 0, y: 9)), CGPoint(x: 32, y: 32))
        XCTAssertEqual(layout.point(for: Position(x: 11, y: 9)), CGPoint(x: 736, y: 32))
    }

    func testPointToTileRoundTrips() {
        for y in 0..<layout.height {
            for x in 0..<layout.width {
                let tile = Position(x: x, y: y)
                XCTAssertEqual(layout.position(at: layout.point(for: tile)), tile)
            }
        }
    }

    func testTapsNearTileEdgesLandOnTheRightTile() {
        // Just inside the top-left tile, and just inside its bottom-right corner.
        XCTAssertEqual(layout.position(at: CGPoint(x: 1, y: 639)), Position(x: 0, y: 0))
        XCTAssertEqual(layout.position(at: CGPoint(x: 63, y: 577)), Position(x: 0, y: 0))
        // A tile owns its lower edge: y = 576 is still row 0, y = 575 is row 1.
        XCTAssertEqual(layout.position(at: CGPoint(x: 64, y: 576)), Position(x: 1, y: 0))
        XCTAssertEqual(layout.position(at: CGPoint(x: 64, y: 575)), Position(x: 1, y: 1))
    }

    func testPointsOffTheBoardHaveNoTile() {
        XCTAssertNil(layout.position(at: CGPoint(x: -1, y: 10)))
        XCTAssertNil(layout.position(at: CGPoint(x: 10, y: -1)))
        XCTAssertNil(layout.position(at: CGPoint(x: 768, y: 10)))
        XCTAssertNil(layout.position(at: CGPoint(x: 10, y: 640)))
    }

    func testLayoutFromMapMatchesTheGrid() throws {
        let map = try GameMap(ascii: Maps.crossing)
        let fromMap = BoardLayout(map: map, tileSize: 64)
        XCTAssertEqual(fromMap.width, map.width)
        XCTAssertEqual(fromMap.height, map.height)
    }

    func testScaleToFitShrinksButNeverEnlarges() {
        // Half-size container: the board must be halved.
        XCTAssertEqual(layout.scaleToFit(CGSize(width: 384, height: 320)), 0.5, accuracy: 0.0001)
        // Plenty of room: stay at 1:1 rather than upscaling the art.
        XCTAssertEqual(layout.scaleToFit(CGSize(width: 2000, height: 2000)), 1.0)
        // Padding counts against the available space.
        XCTAssertLessThan(layout.scaleToFit(CGSize(width: 768, height: 640), padding: 20), 1.0)
    }
}
