import XCTest
import SpriteKit
import TankGameCore
@testable import TankGameRendering

/// The frame around the field and the typography the HUD and buttons share.
/// Both are drawn in code, so the things worth pinning down are the geometry
/// (the border must stay on screen) and the fallbacks (a font the device lacks
/// must not silently ruin a layout).
@MainActor
final class BoardFrameNodeTests: XCTestCase {

    func testFrameThicknessScalesWithTheTileButHasAFloor() {
        XCTAssertEqual(BoardFrameNode.inset(forTileSize: 64), 27)
        XCTAssertEqual(BoardFrameNode.inset(forTileSize: 100), 42)
        // A tiny tile would otherwise give a border too thin to read as one.
        XCTAssertEqual(BoardFrameNode.inset(forTileSize: 20), 14)
    }

    func testFrameSurroundsTheGridOnEverySide() {
        let boardSize = CGSize(width: 768, height: 640)
        let frame = BoardFrameNode(boardSize: boardSize, tileSize: 64, theme: .standard)

        XCTAssertEqual(frame.outerSize.width, boardSize.width + frame.inset * 2)
        XCTAssertEqual(frame.outerSize.height, boardSize.height + frame.inset * 2)
    }

    func testFrameDrawsBehindTheTerrain() {
        let frame = BoardFrameNode(boardSize: CGSize(width: 320, height: 320),
                                   tileSize: 64, theme: .standard)
        // BoardNode puts terrain at zPosition 0 in the same space, and the
        // frame is the later sibling — so every layer of it, not just the node,
        // has to sit below 0 or the plate paints over the tiles.
        XCTAssertFalse(frame.children.isEmpty)
        for layer in frame.children {
            XCTAssertLessThan(frame.zPosition + layer.zPosition, 0,
                              "frame layer at \(layer.zPosition) would cover the terrain")
        }
    }

    /// The whole point of `outset`: at the same screen size, making room for the
    /// border has to shrink the board, or the frame would hang off the edge.
    func testScaleToFitReservesRoomForTheFrame() {
        let layout = BoardLayout(width: 12, height: 10, tileSize: 64)
        let screen = CGSize(width: 390, height: 600)

        let bare = layout.scaleToFit(screen, padding: 6)
        let framed = layout.scaleToFit(screen, padding: 6, outset: 27)
        XCTAssertLessThan(framed, bare)

        // And the frame then fits inside the usable width.
        let used = (layout.size.width + 27 * 2) * framed
        XCTAssertLessThanOrEqual(used, screen.width - 12 + 0.001)
    }

    func testZeroOutsetMatchesTheOldBehaviour() {
        let layout = BoardLayout(width: 12, height: 10, tileSize: 64)
        XCTAssertEqual(layout.scaleToFit(CGSize(width: 384, height: 320), outset: 0),
                       0.5, accuracy: 0.0001)
    }
}

@MainActor
final class TextStyleTests: XCTestCase {

    func testResolvePicksAnInstalledFont() {
        // Helvetica is the last resort in both stacks and exists everywhere.
        XCTAssertNotNil(PlatformFont(name: BoardFonts.resolve(BoardFonts.display), size: 12))
        XCTAssertNotNil(PlatformFont(name: BoardFonts.resolve(BoardFonts.readout), size: 12))
    }

    func testResolveFallsThroughUnknownNames() {
        XCTAssertEqual(BoardFonts.resolve(["NotAFont-Regular", "Helvetica"]), "Helvetica")
        // Nothing installed: the last candidate is returned rather than nil, so
        // the label still gets a name to try.
        XCTAssertEqual(BoardFonts.resolve(["NotAFont-Regular", "AlsoNotAFont"]), "AlsoNotAFont")
    }

    func testTrackedStyleSetsCapsAndKerning() throws {
        let style = TextStyle(size: 18, color: .white, tracking: 2, uppercase: true)
        let attributed = style.attributed("Attack")
        XCTAssertEqual(attributed.string, "ATTACK")

        let kern = attributed.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat
        XCTAssertEqual(try XCTUnwrap(kern), 2)
    }

    /// A label that once carried an attributed string has to be cleared, or the
    /// plain `fontColor`/`fontSize` it is given next are ignored.
    func testApplyingAnUntrackedStyleClearsAttributedText() {
        let tracked = TextStyle(size: 18, color: .white, tracking: 2, uppercase: true)
        let plain = TextStyle(size: 14, color: .red)
        let label = tracked.makeLabel("Round 1")
        XCTAssertNotNil(label.attributedText)

        plain.apply(to: label, text: "Round 2")
        XCTAssertNil(label.attributedText)
        XCTAssertEqual(label.text, "Round 2")
        XCTAssertEqual(label.fontSize, 14)
    }

    func testSizedAndColoredLeaveTheRestOfTheStyleAlone() {
        let base = TextStyle(size: 20, color: .white, tracking: 1.5, uppercase: true)
        let derived = base.sized(12).colored(.red)
        XCTAssertEqual(derived.size, 12)
        XCTAssertEqual(derived.tracking, 1.5)
        XCTAssertTrue(derived.uppercase)
        XCTAssertEqual(derived.fontName, base.fontName)
    }
}

@MainActor
final class ButtonStyleTests: XCTestCase {

    func testEachStyleGetsItsOwnFillSoFiringNeverLooksLikeCancelling() {
        let theme = BoardTheme.standard
        let danger = theme.palette(for: .danger)
        let confirm = theme.palette(for: .confirm)
        let neutral = theme.palette(for: .neutral)

        XCTAssertNotEqual(danger.fill, neutral.fill)
        XCTAssertNotEqual(confirm.fill, neutral.fill)
        XCTAssertNotEqual(danger.fill, confirm.fill)
        XCTAssertNotEqual(theme.disabledPalette.text, neutral.text)
    }

    func testTitleSurvivesTheUppercaseRoundTrip() {
        let button = ButtonNode(identifier: "attack", title: "Attack",
                                size: CGSize(width: 90, height: 40),
                                theme: .standard, style: .danger)
        XCTAssertEqual(button.title, "ATTACK")

        button.title = "Wait"
        XCTAssertEqual(button.title, "WAIT")
    }

    /// Disabling restyles the plate; it must not drop the caption on the way.
    func testDisablingKeepsTheCaption() {
        let button = ButtonNode(identifier: "pass", title: "Pass",
                                size: CGSize(width: 90, height: 40),
                                theme: .standard)
        button.isEnabled = false
        XCTAssertEqual(button.title, "PASS")
        XCTAssertFalse(button.isTappable)

        button.isEnabled = true
        XCTAssertEqual(button.title, "PASS")
    }
}
