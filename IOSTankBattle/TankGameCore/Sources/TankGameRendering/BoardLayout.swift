import CoreGraphics
import TankGameCore

/// Converts between grid coordinates and points inside the board node.
///
/// The model's y axis grows DOWNWARD (row 0 is the top row), SpriteKit's grows
/// upward, so every conversion flips y. Board-local (0, 0) is the bottom-left
/// corner of the grid, which makes the board easy to center in a scene.
public struct BoardLayout: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let tileSize: CGFloat

    public init(width: Int, height: Int, tileSize: CGFloat = 64) {
        self.width = width
        self.height = height
        self.tileSize = tileSize
    }

    public init(map: GameMap, tileSize: CGFloat = 64) {
        self.init(width: map.width, height: map.height, tileSize: tileSize)
    }

    public var size: CGSize {
        CGSize(width: CGFloat(width) * tileSize, height: CGFloat(height) * tileSize)
    }

    /// The center of a tile, in board-local points.
    public func point(for position: Position) -> CGPoint {
        CGPoint(x: (CGFloat(position.x) + 0.5) * tileSize,
                y: (CGFloat(height - 1 - position.y) + 0.5) * tileSize)
    }

    /// The tile under a board-local point, or nil if the point is off the grid.
    public func position(at point: CGPoint) -> Position? {
        guard point.x >= 0, point.y >= 0, point.x < size.width, point.y < size.height else {
            return nil
        }
        let column = Int(point.x / tileSize)
        let row = height - 1 - Int(point.y / tileSize)
        let position = Position(x: column, y: row)
        return contains(position) ? position : nil
    }

    public func contains(_ position: Position) -> Bool {
        position.x >= 0 && position.x < width && position.y >= 0 && position.y < height
    }

    /// The scale that fits the whole board inside `container`, never above 1 so
    /// a small board is not blown up past its art resolution.
    ///
    /// `outset` is board-local space that has to fit alongside the grid on every
    /// side — the border frame, which scales with the board — so passing it
    /// keeps the frame on screen instead of over the edge.
    public func scaleToFit(_ container: CGSize, padding: CGFloat = 0,
                           outset: CGFloat = 0) -> CGFloat {
        let usable = CGSize(width: max(container.width - padding * 2, 1),
                            height: max(container.height - padding * 2, 1))
        let needed = CGSize(width: size.width + outset * 2, height: size.height + outset * 2)
        guard needed.width > 0, needed.height > 0 else { return 1 }
        return min(1, min(usable.width / needed.width, usable.height / needed.height))
    }
}
