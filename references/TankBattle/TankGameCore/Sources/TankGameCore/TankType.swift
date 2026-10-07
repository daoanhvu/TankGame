/// The three tank classes in phase 1.
public enum TankKind: String, Codable, Sendable, CaseIterable {
    case light
    case medium
    case artillery
}

/// Static, balance-related stats for one tank class.
/// Kept as data (not logic) so balancing never requires code changes.
public struct TankStats: Codable, Equatable, Sendable {
    public let movePoints: Int
    /// Inclusive weapon range in Manhattan distance.
    /// `minRange > 1` means the tank cannot fire at adjacent targets.
    public let minRange: Int
    public let maxRange: Int
    public let maxHP: Int
    /// Fixed damage per shot (no randomness in phase 1).
    public let damage: Int
    public let maxAmmo: Int

    public init(movePoints: Int, minRange: Int, maxRange: Int,
                maxHP: Int, damage: Int, maxAmmo: Int) {
        self.movePoints = movePoints
        self.minRange = minRange
        self.maxRange = maxRange
        self.maxHP = maxHP
        self.damage = damage
        self.maxAmmo = maxAmmo
    }

    /// True if a target at `distance` is inside this weapon's range band.
    public func canReach(distance: Int) -> Bool {
        distance >= minRange && distance <= maxRange
    }
}

/// Lets `[TankKind: X]` encode as a JSON object ("key": value) instead of an array.
extension TankKind: CodingKeyRepresentable {}
