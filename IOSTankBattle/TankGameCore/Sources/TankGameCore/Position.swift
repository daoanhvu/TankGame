/// A tile coordinate on the grid. Origin (0, 0) is the top-left corner;
/// `x` grows to the right (columns), `y` grows downward (rows).
public struct Position: Hashable, Codable, Sendable, CustomStringConvertible {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    /// Grid-step distance. Used for both weapon range and (via path costs) movement.
    public func manhattanDistance(to other: Position) -> Int {
        abs(x - other.x) + abs(y - other.y)
    }

    /// The four orthogonal neighbours (no diagonals in phase 1).
    /// Bounds are NOT checked here; the map filters out-of-range tiles.
    public var orthogonalNeighbors: [Position] {
        [
            Position(x: x, y: y - 1),
            Position(x: x + 1, y: y),
            Position(x: x, y: y + 1),
            Position(x: x - 1, y: y),
        ]
    }

    public var description: String { "(\(x), \(y))" }
}
