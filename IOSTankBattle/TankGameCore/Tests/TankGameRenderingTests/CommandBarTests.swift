import XCTest
import SpriteKit
import TankGameCore
@testable import TankGameRendering

/// The command bar's cells are flat — no fill, no rim — so the thing most
/// likely to break is the one that matters: that a tap anywhere in a cell,
/// not just on its icon or caption, reaches the button.
@MainActor
final class CommandBarTests: XCTestCase {

    private func makeScene() throws -> (SKScene, HUDNode) {
        let size = CGSize(width: 402, height: 874)
        let scene = SKScene(size: size)
        scene.anchorPoint = .zero
        let hud = HUDNode(sceneSize: size, insets: BoardInsets(top: 59, bottom: 34),
                          theme: .standard,
                          catalog: SpriteCatalog(bundle: Bundle(for: CommandBarTests.self)))
        scene.addChild(hud)
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.presentScene(scene)
        return (scene, hud)
    }

    func testEveryCommandIsTappableAcrossItsWholeCell() throws {
        let (_, hud) = try makeScene()
        // Moving and attacking are taps on the board; only two commands remain.
        let expected = [HUDNode.ButtonID.cancel, HUDNode.ButtonID.pass]
        let cellWidth = 402.0 / 2.0
        // A band inside each cell, away from the icon and the caption.
        let y = 34.0 + 10.0

        for (index, identifier) in expected.enumerated() {
            for fraction in [0.15, 0.5, 0.85] {
                let x = cellWidth * (Double(index) + fraction)
                let hit = hud.button(atScenePoint: CGPoint(x: x, y: y))
                XCTAssertEqual(hit?.identifier, identifier,
                               "no hit at \(Int(fraction * 100))% across the \(identifier) cell")
            }
        }
    }

    func testTapsAboveTheBarDoNotHitACommand() throws {
        let (_, hud) = try makeScene()
        // Well up in the board area: the board must get this, not the HUD.
        XCTAssertNil(hud.button(atScenePoint: CGPoint(x: 200, y: 500)))
    }

    func testDisabledCommandsAreNotTappable() throws {
        let (_, hud) = try makeScene()
        let state = try GameState.newGame(config: .phase1Default,
                                          map: try GameMap(ascii: Maps.crossing))
        hud.update(with: BoardInteraction(state: state))

        // Nothing is selected, so there is nothing to cancel.
        let cellWidth = 402.0 / 2.0
        let y = 34.0 + 10.0
        XCTAssertNil(hud.button(atScenePoint: CGPoint(x: cellWidth * 0.5, y: y)))
        XCTAssertEqual(hud.button(atScenePoint: CGPoint(x: cellWidth * 1.5, y: y))?.identifier,
                       HUDNode.ButtonID.pass, "End Turn is always available")
    }

    func testSectorReadsAsAMapReference() {
        XCTAssertEqual(HUDNode.sector(of: Position(x: 0, y: 0)), "A-1")
        XCTAssertEqual(HUDNode.sector(of: Position(x: 2, y: 3)), "C-4")
        XCTAssertEqual(HUDNode.sector(of: Position(x: 11, y: 9)), "L-10")
    }
}

/// The HUD carries ONE unit card, above the field, and it has to describe a tank
/// of either side: with the second card gone, a card that only ever read the
/// side to move would leave a tapped enemy reporting nothing at all.
@MainActor
final class UnitCardTests: XCTestCase {

    private func makeHUD() -> HUDNode {
        let size = CGSize(width: 402, height: 874)
        let scene = SKScene(size: size)
        scene.anchorPoint = .zero
        let hud = HUDNode(sceneSize: size, insets: BoardInsets(top: 59, bottom: 34),
                          theme: .standard,
                          catalog: SpriteCatalog(bundle: Bundle(for: UnitCardTests.self)))
        scene.addChild(hud)
        return hud
    }

    func testTheOneCardDescribesWhicheverSideIsInFocus() throws {
        let state = try GameState.newGame(config: .phase1Default,
                                          map: try GameMap(ascii: Maps.crossing))
        var interaction = BoardInteraction(state: state)
        let hud = makeHUD()

        // Nothing in focus yet, so the card stands empty rather than guessing.
        hud.update(with: interaction)
        XCTAssertNil(hud.unitCard.shownSide)
        XCTAssertNil(hud.unitCard.shownKind)

        // The player's own tank, selected.
        let mine = try XCTUnwrap(state.tanks.first { $0.side == .player && $0.isAlive })
        interaction.tapTile(mine.position)
        hud.update(with: interaction)
        XCTAssertEqual(hud.unitCard.shownSide, .player)
        XCTAssertEqual(hud.unitCard.shownKind, mine.kind)

        // An enemy across the map, too far to shoot, so the tap inspects it.
        // The same card has to swap over to it: this is the whole reason the
        // card is shared.
        let theirs = try XCTUnwrap(state.tanks.first { $0.side == .ai && $0.isAlive })
        interaction.tapTile(theirs.position)
        XCTAssertEqual(interaction.inspectedTankID, theirs.id, "expected an out-of-range tap to inspect")
        hud.update(with: interaction)
        XCTAssertEqual(hud.unitCard.shownSide, .ai)
        XCTAssertEqual(hud.unitCard.shownKind, theirs.kind)

        // Cancelling drops the focus, and the card empties again.
        interaction.cancel()
        hud.update(with: interaction)
        XCTAssertNil(hud.unitCard.shownSide)
    }

    /// The bottom panel is now the status line and the command bar only, so it
    /// must no longer reserve a card's height — that room belongs to the board.
    func testBottomInsetNoLongerReservesRoomForACard() {
        let hud = makeHUD()
        XCTAssertEqual(hud.bottomInset, 34 + 64 + 22 + 10)
        XCTAssertLessThan(hud.bottomInset, hud.topInset,
                          "the single card lives up top, so the top bar is the taller one")
    }
}
