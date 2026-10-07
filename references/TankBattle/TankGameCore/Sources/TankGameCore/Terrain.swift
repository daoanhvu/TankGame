/// Terrain types for phase 1.
///
/// | Terrain | Passable | Move cost |
/// |---------|----------|-----------|
/// | open    | yes      | 1         |
/// | trees   | yes      | 2         |
/// | rocks   | no       | -         |
/// | water   | no       | -         |
///
/// No terrain blocks shots (line of sight is out of scope).
public enum Terrain: String, Codable, Sendable, CaseIterable {
    case open
    case trees
    case rocks
    case water

    public var isPassable: Bool {
        switch self {
        case .open, .trees: return true
        case .rocks, .water: return false
        }
    }

    /// Movement points needed to ENTER this tile, or nil if it cannot be entered.
    public var moveCost: Int? {
        switch self {
        case .open: return 1
        case .trees: return 2
        case .rocks, .water: return nil
        }
    }
}
