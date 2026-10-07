/// The two warring parties.
public enum Side: String, Codable, Sendable, CaseIterable {
    case player
    case ai

    public var opponent: Side {
        self == .player ? .ai : .player
    }
}

/// Lets `[Side: X]` encode as a JSON object ("key": value) instead of an array.
extension Side: CodingKeyRepresentable {}
