import SpriteKit
import TankGameCore

/// The border around the playing field: a bevelled gunmetal plate with a brass
/// inner rule, corner brackets and bolts.
///
/// Drawn in code, like every other piece of UI, so it survives the art swap in
/// milestone 4 and costs nothing to retheme. It sits BEHIND `BoardNode` in the
/// same coordinate space, with the grid occupying
/// `(0, 0) ... (boardSize.width, boardSize.height)`, and it extends `inset`
/// points outward on every side — which is why the scene has to reserve room
/// for it before scaling the board to fit.
@MainActor
public final class BoardFrameNode: SKNode {

    /// How far the frame reaches outside the grid, scaled off the tile so a
    /// bigger board gets a proportionally heavier frame.
    ///
    /// Generous on purpose: a 12x10 field is scaled to about half size to fit a
    /// phone, and the frame scales with it, so a border that looks right in
    /// board-local points reads as a hairline on the device.
    public static func inset(forTileSize tileSize: CGFloat) -> CGFloat {
        max(14, (tileSize * 0.42).rounded())
    }

    public let inset: CGFloat

    public init(boardSize: CGSize, tileSize: CGFloat, theme: BoardTheme) {
        self.inset = Self.inset(forTileSize: tileSize)
        super.init()
        // Well below the terrain, which BoardNode draws at 0. The frame's own
        // layers stack from 0 upward inside this node, so the whole assembly has
        // to clear that range or its plate would tie with the tiles and, being
        // the later sibling, paint over them.
        zPosition = -10
        build(boardSize: boardSize, theme: theme)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// The frame's full footprint, grid plus border, for layout maths.
    public var outerSize: CGSize {
        CGSize(width: frameRect.width, height: frameRect.height)
    }

    private var frameRect: CGRect = .zero

    private func build(boardSize: CGSize, theme: BoardTheme) {
        let center = CGPoint(x: boardSize.width / 2, y: boardSize.height / 2)
        frameRect = CGRect(origin: .zero, size: boardSize).insetBy(dx: -inset, dy: -inset)

        /// Every layer is a rounded rect centred on the grid; `grow` is how far
        /// outside the grid's edge that layer sits.
        func plate(grow: CGFloat, radius: CGFloat) -> SKShapeNode {
            let node = SKShapeNode(rectOf: CGSize(width: boardSize.width + grow * 2,
                                                  height: boardSize.height + grow * 2),
                                   cornerRadius: radius)
            node.position = center
            node.fillColor = .clear
            node.strokeColor = .clear
            return node
        }

        // 1. The shadow the whole assembly casts on the background.
        let shadow = plate(grow: inset, radius: inset * 0.6)
        shadow.fillColor = theme.framePlateEdge
        shadow.alpha = 0.75
        shadow.position.y -= inset * 0.22
        shadow.zPosition = 0
        addChild(shadow)

        // 2. The plate, with a dark machined outer edge.
        let body = plate(grow: inset, radius: inset * 0.6)
        body.fillColor = theme.framePlate
        body.strokeColor = theme.framePlateEdge
        body.lineWidth = 2
        body.zPosition = 1
        addChild(body)

        // 3. Bevel: a lit line just inside the outer edge, a dark one below it.
        let highlight = plate(grow: inset - 2.5, radius: inset * 0.45)
        highlight.strokeColor = theme.frameHighlight
        highlight.lineWidth = 2
        highlight.zPosition = 2
        addChild(highlight)

        let shade = plate(grow: inset - 5, radius: inset * 0.4)
        shade.strokeColor = SKColor(white: 0, alpha: 0.28)
        shade.lineWidth = 2
        shade.zPosition = 2
        addChild(shade)

        // 4. Brass rule hugging the grid, the frame's one bright accent.
        let rule = plate(grow: 4, radius: 3)
        rule.strokeColor = theme.frameAccent
        rule.lineWidth = 2
        rule.zPosition = 3
        addChild(rule)

        // 5. A dark lip so the field reads as recessed into the plate.
        let lip = plate(grow: 1.5, radius: 2)
        lip.strokeColor = SKColor(white: 0, alpha: 0.45)
        lip.lineWidth = 3
        lip.zPosition = 3
        addChild(lip)

        addCornerBrackets(boardSize: boardSize, theme: theme)
        addBolts(boardSize: boardSize, theme: theme)
    }

    /// Short L-shaped marks in the plate's corners: map-case furniture, and a
    /// cheap way to make the rectangle feel built rather than drawn.
    private func addCornerBrackets(boardSize: CGSize, theme: BoardTheme) {
        let length = inset * 1.6
        let offset = inset * 0.52
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: -offset, y: -offset), 1, 1),                                  // bottom-left
            (CGPoint(x: boardSize.width + offset, y: -offset), -1, 1),                // bottom-right
            (CGPoint(x: -offset, y: boardSize.height + offset), 1, -1),               // top-left
            (CGPoint(x: boardSize.width + offset, y: boardSize.height + offset), -1, -1),
        ]
        for (origin, sx, sy) in corners {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: origin.x + sx * length, y: origin.y))
            path.addLine(to: origin)
            path.addLine(to: CGPoint(x: origin.x, y: origin.y + sy * length))
            let bracket = SKShapeNode(path: path)
            bracket.strokeColor = theme.frameAccent.withAlphaComponent(0.55)
            bracket.lineWidth = 2
            bracket.lineCap = .square
            bracket.zPosition = 4
            addChild(bracket)
        }
    }

    /// Bolts at the corners of the plate, each with a highlight so it reads as
    /// round rather than as a dot.
    private func addBolts(boardSize: CGSize, theme: BoardTheme) {
        let radius = max(2.5, inset * 0.17)
        let offset = inset * 0.5
        let points = [
            CGPoint(x: -offset, y: -offset),
            CGPoint(x: boardSize.width + offset, y: -offset),
            CGPoint(x: -offset, y: boardSize.height + offset),
            CGPoint(x: boardSize.width + offset, y: boardSize.height + offset),
            CGPoint(x: boardSize.width / 2, y: -offset),
            CGPoint(x: boardSize.width / 2, y: boardSize.height + offset),
        ]
        for point in points {
            let bolt = SKShapeNode(circleOfRadius: radius)
            bolt.position = point
            bolt.fillColor = theme.frameRivet
            bolt.strokeColor = theme.framePlateEdge
            bolt.lineWidth = 1
            bolt.zPosition = 5
            addChild(bolt)

            let glint = SKShapeNode(circleOfRadius: radius * 0.38)
            glint.position = CGPoint(x: -radius * 0.25, y: radius * 0.25)
            glint.fillColor = theme.frameHighlight
            glint.strokeColor = .clear
            bolt.addChild(glint)
        }
    }
}
