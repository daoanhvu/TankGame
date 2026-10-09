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

    /// How far the frame reaches outside the grid. Slim, matching
    /// `docs/ScreenDesign.png`: the field is bordered, not framed.
    public static func inset(forTileSize tileSize: CGFloat) -> CGFloat {
        max(6, (tileSize * 0.14).rounded())
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

        /// Every layer is a rect centred on the grid; `grow` is how far outside
        /// the grid's edge that layer sits.
        func plate(grow: CGFloat, radius: CGFloat) -> SKShapeNode {
            let node = SKShapeNode(rectOf: CGSize(width: boardSize.width + grow * 2,
                                                  height: boardSize.height + grow * 2),
                                   cornerRadius: radius)
            node.position = center
            node.fillColor = .clear
            node.strokeColor = .clear
            return node
        }

        // 1. A quiet mat the field sits on, a shade off the scene background.
        let body = plate(grow: inset, radius: 3)
        body.fillColor = theme.framePlate
        body.strokeColor = theme.framePlateEdge
        body.lineWidth = 1
        body.zPosition = 1
        addChild(body)

        // 2. The border itself: one amber hairline hugging the grid.
        let rule = plate(grow: 2, radius: 2)
        rule.strokeColor = theme.frameAccent.withAlphaComponent(0.55)
        rule.lineWidth = 1
        rule.zPosition = 2
        addChild(rule)

        // 3. Corner ticks, the one piece of decoration the field keeps.
        addCornerTicks(boardSize: boardSize, theme: theme)
    }

    /// Short L marks just outside the border's corners.
    private func addCornerTicks(boardSize: CGSize, theme: BoardTheme) {
        let length = inset * 1.4
        let offset = inset * 0.5
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: -offset, y: -offset), 1, 1),
            (CGPoint(x: boardSize.width + offset, y: -offset), -1, 1),
            (CGPoint(x: -offset, y: boardSize.height + offset), 1, -1),
            (CGPoint(x: boardSize.width + offset, y: boardSize.height + offset), -1, -1),
        ]
        for (origin, sx, sy) in corners {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: origin.x + sx * length, y: origin.y))
            path.addLine(to: origin)
            path.addLine(to: CGPoint(x: origin.x, y: origin.y + sy * length))
            let tick = SKShapeNode(path: path)
            tick.strokeColor = theme.frameAccent.withAlphaComponent(0.8)
            tick.lineWidth = 1.5
            tick.lineCap = .square
            tick.zPosition = 3
            addChild(tick)
        }
    }
}
