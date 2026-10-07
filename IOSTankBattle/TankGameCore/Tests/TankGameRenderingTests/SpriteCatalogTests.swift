import XCTest
import SpriteKit
import TankGameCore
@testable import TankGameRendering

final class AssetNameTests: XCTestCase {
    func testNamingConvention() {
        XCTAssertEqual(AssetName.tank(.light, .player), "tank_light_player")
        XCTAssertEqual(AssetName.tank(.artillery, .ai), "tank_artillery_ai")
        XCTAssertEqual(AssetName.tankBarrel(.medium, .player), "tank_medium_player_barrel")
        XCTAssertEqual(AssetName.terrain(.water), "terrain_water")
        XCTAssertEqual(AssetName.supply(.ai), "supply_ai")
        XCTAssertEqual(AssetName.effect(.muzzleFlash), "fx_muzzle_flash")
    }

    func testRequiredListIsCompleteAndUnique() {
        let required = AssetName.required
        // 4 terrains + 2 supplies + 3 effects. Tank hulls come from the atlas,
        // so they are deliberately not on this list.
        XCTAssertEqual(required.count, 9)
        XCTAssertEqual(Set(required).count, required.count)
        XCTAssertTrue(Set(required).isDisjoint(with: AssetName.optional))
        XCTAssertFalse(required.contains(AssetName.tank(.light, .player)))
    }
}

@MainActor
final class SpriteCatalogTests: XCTestCase {
    /// The test bundle contains no images, so everything must fall back to placeholders.
    private func makeCatalog() -> SpriteCatalog {
        SpriteCatalog(tileSize: 64, bundle: Bundle(for: SpriteCatalogTests.self))
    }

    func testTankFallsBackToPlaceholder() {
        let node = makeCatalog().tankNode(kind: .light, side: .player)
        XCTAssertNotNil(node.childNode(withName: SpriteCatalog.NodeName.placeholder))
        XCTAssertNil(node.childNode(withName: SpriteCatalog.NodeName.body))
    }

    func testPlaceholderUsesSideColor() throws {
        let catalog = makeCatalog()
        let node = catalog.tankNode(kind: .medium, side: .ai)
        let shape = try XCTUnwrap(node.childNode(withName: SpriteCatalog.NodeName.placeholder) as? SKShapeNode)
        XCTAssertEqual(shape.fillColor, catalog.palette.color(for: .ai))
    }

    func testTerrainAndSupplyFallBackToPlaceholders() {
        let catalog = makeCatalog()
        for terrain in Terrain.allCases {
            XCTAssertEqual(catalog.terrainNode(terrain).name, SpriteCatalog.NodeName.placeholder)
        }
        for side in Side.allCases {
            XCTAssertEqual(catalog.supplyNode(side).name, SpriteCatalog.NodeName.placeholder)
        }
    }

    func testMissingAssetsReportListsEverythingWhenBundleIsEmpty() {
        let catalog = makeCatalog()
        XCTAssertEqual(catalog.missingRequiredAssets(), AssetName.required)
        XCTAssertNil(catalog.effectTexture(.explosion))
    }
}
