import XCTest
import SpriteKit
import TankGameCore
@testable import TankGameRendering

/// The atlas itself cannot be loaded here — the test bundle carries no
/// resources — which is exactly the case these tests have to pin down: no
/// atlas must mean placeholders, never a crash. The pure geometry is tested
/// directly.
@MainActor
final class TankAtlasTests: XCTestCase {

    func testMissingAtlasIsNilRatherThanAFailure() {
        XCTAssertNil(TankAtlas(bundle: Bundle(for: TankAtlasTests.self)))
    }

    func testCatalogStillDrawsPlaceholdersWithoutAnAtlas() {
        let catalog = SpriteCatalog(tileSize: 64, bundle: Bundle(for: TankAtlasTests.self))
        XCTAssertNil(catalog.atlas)
        let node = catalog.tankNode(kind: .medium, side: .ai)
        XCTAssertNotNil(node.childNode(withName: SpriteCatalog.NodeName.placeholder))
    }

    /// The y flip between the JSON's top-left pixels and SpriteKit's
    /// bottom-left normalised rects. Hand-computed: a 100x50 frame at (20, 10)
    /// in a 200x100 image.
    func testNormalizedRectFlipsY() {
        let rect = TankAtlas.normalizedRect(CGRect(x: 20, y: 10, width: 100, height: 50),
                                            in: CGSize(width: 200, height: 100))
        XCTAssertEqual(rect.minX, 0.10, accuracy: 0.0001)
        XCTAssertEqual(rect.width, 0.50, accuracy: 0.0001)
        XCTAssertEqual(rect.height, 0.50, accuracy: 0.0001)
        // Top edge 10px down in a 100px image -> bottom edge at 1 - 60/100.
        XCTAssertEqual(rect.minY, 0.40, accuracy: 0.0001)
    }

    func testNormalizedRectCoversTheWholeImage() {
        let rect = TankAtlas.normalizedRect(CGRect(x: 0, y: 0, width: 200, height: 100),
                                            in: CGSize(width: 200, height: 100))
        XCTAssertEqual(rect, CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    func testNormalizedRectOfAnEmptyImageIsZeroRatherThanNaN() {
        XCTAssertEqual(TankAtlas.normalizedRect(CGRect(x: 0, y: 0, width: 10, height: 10),
                                                in: .zero), .zero)
    }

    func testDrivingLoopReturnsToTheMiddleFrame() {
        // There and back, so a looping drive never jumps from move3 to move1.
        XCTAssertEqual(TankAnimation.driving, [.move1, .move2, .move3, .move2])
    }

    func testEveryAnimationNameMatchesTheAtlasFrameNames() {
        // The raw values are the JSON's keys; a typo here is a silent nil.
        XCTAssertEqual(Set(TankAnimation.allCases.map(\.rawValue)),
                       ["idle", "move1", "move2", "move3", "fire", "destroyed"])
    }
}

final class TankSkinTests: XCTestCase {

    func testEachSideGetsItsOwnHull() {
        XCTAssertEqual(TankSkin.atlasSet(for: .player), "ally")
        XCTAssertEqual(TankSkin.atlasSet(for: .ai), "enemy")
        XCTAssertNotEqual(TankSkin.atlasSet(for: .player), TankSkin.atlasSet(for: .ai))
    }

    /// Light has to be visibly smaller; medium and artillery are close on
    /// purpose (the HUD tells them apart), but must not be identical.
    func testKindsAreSizedApart() {
        let light = TankSkin.hullFraction(for: .light)
        let medium = TankSkin.hullFraction(for: .medium)
        let artillery = TankSkin.hullFraction(for: .artillery)
        XCTAssertLessThan(light, artillery)
        XCTAssertLessThan(artillery, medium)
        for fraction in [light, medium, artillery] {
            XCTAssertGreaterThan(fraction, 0.4)
            XCTAssertLessThanOrEqual(fraction, 1.0)
        }
    }
}
